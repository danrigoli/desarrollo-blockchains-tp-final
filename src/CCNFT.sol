// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title CCNFT
 * @notice Colección ERC‑721 que se compra, comercia y reclama usando un token
 *         ERC‑20 (por ejemplo BUSD). Soporta: buy(), claim(), trade(), putOnSale().
 */
contract CCNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    /* -------------------------------------------------------------------------- */
    /*                                   EVENTOS                                  */
    /* -------------------------------------------------------------------------- */

    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value);
    event Claim(address indexed claimer, uint256 indexed tokenId);
    event Trade(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 value
    );
    event PutOnSale(uint256 indexed tokenId, uint256 price);

    /* -------------------------------------------------------------------------- */
    /*                                   ESTADO                                   */
    /* -------------------------------------------------------------------------- */

    struct TokenSale {
        bool onSale;
        uint256 price;
    }

    using Counters for Counters.Counter;
    using Strings  for uint256;
    Counters.Counter private _tokenIdTracker;

    // tokenId  ➜ valor base del NFT
    mapping(uint256 => uint256) public values;
    // valor permitido (true ⇒ se puede mintear a ese precio)
    mapping(uint256 => bool)   public validValues;
    // tokenId  ➜ info de venta
    mapping(uint256 => TokenSale) public tokensOnSale;
    // listado de todos los tokens en venta (para UI)
    uint256[] public listTokensOnSale;

    IERC20  public fundsToken;      // ERC‑20 usado como medio de pago
    address public fundsCollector;  // recibe el pago neto de cada buy()
    address public feesCollector;   // recibe las comisiones (buyFee / tradeFee)

    bool    public canBuy  = true;
    bool    public canClaim = true;
    bool    public canTrade = true;

    uint256 public totalValue;        // suma de todos los "values" circulando
    uint256 public maxValueToRaise;   // techo de recaudación en buy()

    uint16  public buyFee;            // ej. 250 ⇒ 2,50 %
    uint16  public tradeFee;          // idem para trade()

    uint16  public maxBatchCount = 50; // protección de gas en bucles
    uint32  public profitToPay;        // % extra que se paga en claim()

    string private constant _SVG_IMAGE = string(
        abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
            '<rect width="100%" height="100%" fill="#222"/>',
            '<text x="50%" y="50%" dominant-baseline="middle" ',
            'text-anchor="middle" font-size="24" fill="#fff">CCNFT</text>',
            '</svg>'
        )
    );

    /* -------------------------------------------------------------------------- */
    /*                                CONSTRUCTOR                                 */
    /* -------------------------------------------------------------------------- */

    constructor(
        string memory name_,
        string memory symbol_,
        address fundsToken_,
        address fundsCollector_,
        address feesCollector_
    ) ERC721(name_, symbol_) {
        require(fundsToken_ != address(0), "Funds token zero");
        require(fundsCollector_ != address(0), "FundsCollector zero");
        require(feesCollector_ != address(0),  "FeesCollector zero");

        fundsToken     = IERC20(fundsToken_);
        fundsCollector = fundsCollector_;
        feesCollector  = feesCollector_;
    }

    /* -------------------------------------------------------------------------- */
    /*                              FUNCIONES PÚBLICAS                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Compra `amount` NFTs al precio unitario `value`.
     * @dev Requiere allowance suficiente al CCNFT y valores válidos.
     */
    function buy(uint256 value, uint256 amount) external nonReentrant {
        require(canBuy, "Buy disabled");
        require(amount > 0 && amount <= maxBatchCount, "Bad amount");
        require(validValues[value], "Invalid value");
        require(totalValue + value * amount <= maxValueToRaise, "Cap reached");

        totalValue += value * amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdTracker.current();
            values[tokenId] = value;

            _safeMint(_msgSender(), tokenId);
            emit Buy(_msgSender(), tokenId, value);

            _tokenIdTracker.increment();
        }

        // pago principal al proyecto
        require(
            fundsToken.transferFrom(_msgSender(), fundsCollector, value * amount),
            "Cannot send funds tokens"
        );
        // comisión
        if (buyFee > 0) {
            require(
                fundsToken.transferFrom(
                    _msgSender(),
                    feesCollector,
                    (value * amount * buyFee) / 10_000
                ),
                "Cannot send fees tokens"
            );
        }
    }

    /**
     * @notice Reclama (quema) NFTs y recupera el valor + profit.
     * @param listTokenId lista de tokenIds a reclamar.
     */
    function claim(uint256[] calldata listTokenId) external nonReentrant {
        require(canClaim, "Claim disabled");
        require(
            listTokenId.length > 0 && listTokenId.length <= maxBatchCount,
            "Bad list length"
        );

        uint256 claimValue = 0;
        for (uint256 i = 0; i < listTokenId.length; i++) {
            uint256 id = listTokenId[i];
            require(_exists(id), "Token does not exist");
            require(ownerOf(id) == _msgSender(), "Only owner can claim");

            claimValue += values[id];
            values[id] = 0;

            // si estaba a la venta, lo quitamos
            TokenSale storage ts = tokensOnSale[id];
            ts.onSale = false;
            ts.price  = 0;
            _removeFromArray(id);

            _burn(id);
            emit Claim(_msgSender(), id);
        }

        totalValue -= claimValue;

        uint256 payout = claimValue + (claimValue * profitToPay) / 10_000;
        require(
            fundsToken.transferFrom(fundsCollector, _msgSender(), payout),
            "Cannot send claim funds"
        );
    }

    /**
     * @notice Compra un NFT que está en venta.
     * @param tokenId ID del NFT.
     */
    function trade(uint256 tokenId) external nonReentrant {
        require(canTrade, "Trade disabled");
        require(_exists(tokenId), "Token does not exist");
        address seller = ownerOf(tokenId);
        require(seller != _msgSender(), "Buyer is the Seller");

        TokenSale storage ts = tokensOnSale[tokenId];
        require(ts.onSale, "Token not On Sale");

        // Paga al vendedor
        require(
            fundsToken.transferFrom(_msgSender(), seller, ts.price),
            "Cannot pay seller"
        );
        // Paga la comisión
        if (tradeFee > 0) {
            require(
                fundsToken.transferFrom(
                    _msgSender(),
                    feesCollector,
                    (ts.price * tradeFee) / 10_000
                ),
                "Cannot pay trade fee"
            );
        }

        emit Trade(_msgSender(), seller, tokenId, ts.price);

        _safeTransfer(seller, _msgSender(), tokenId, "");

        ts.onSale = false;
        ts.price  = 0;
        _removeFromArray(tokenId);
    }

    /**
     * @notice Pone un NFT propio a la venta.
     */
    function putOnSale(uint256 tokenId, uint256 price) external {
        require(canTrade, "Trade disabled");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == _msgSender(), "Not owner");

        TokenSale storage ts = tokensOnSale[tokenId];
        ts.onSale = true;
        ts.price  = price;

        _addToArray(tokenId);
        emit PutOnSale(tokenId, price);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   SETTERS                                  */
    /* -------------------------------------------------------------------------- */

    function setFundsToken(address token) external onlyOwner {
        require(token != address(0), "Zero address");
        fundsToken = IERC20(token);
    }

    function setFundsCollector(address _address) external onlyOwner {
        require(_address != address(0), "Zero address");
        fundsCollector = _address;
    }

    function setFeesCollector(address _address) external onlyOwner {
        require(_address != address(0), "Zero address");
        feesCollector = _address;
    }

    function setProfitToPay(uint32 _profitToPay) external onlyOwner {
        profitToPay = _profitToPay;
    }

    function setCanBuy(bool _canBuy) external onlyOwner {
        canBuy = _canBuy;
    }

    function setCanClaim(bool _canClaim) external onlyOwner {
        canClaim = _canClaim;
    }

    function setCanTrade(bool _canTrade) external onlyOwner {
        canTrade = _canTrade;
    }

    function setMaxValueToRaise(uint256 _maxValueToRaise) external onlyOwner {
        maxValueToRaise = _maxValueToRaise;
    }

    function addValidValues(uint256 value) external onlyOwner {
        validValues[value] = true;
    }

    function setMaxBatchCount(uint16 _maxBatchCount) external onlyOwner {
        maxBatchCount = _maxBatchCount;
    }

    function setBuyFee(uint16 _buyFee) external onlyOwner {
        buyFee = _buyFee;
    }

    function setTradeFee(uint16 _tradeFee) external onlyOwner {
        tradeFee = _tradeFee;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   SVG                                     */
    /* -------------------------------------------------------------------------- */

    // Devuelve "data:image/svg+xml;base64,<BASE64-SVG>"
    function _defaultImage() private pure returns (string memory) {
        return string.concat(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(_SVG_IMAGE))
        );
    }

    // JSON on-chain: name, description y la imagen SVG
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(tokenId), "ERC721: invalid token");

        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name":"CCNFT #', tokenId.toString(),
                    '","description":"NFT genérico on-chain",',
                    '"image":"', _defaultImage(), '"}'
                )
            )
        );

        return string.concat("data:application/json;base64,", json);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   ARRAYS                                   */
    /* -------------------------------------------------------------------------- */

    function _addToArray(uint256 value) private {
        uint256 index = _find(listTokensOnSale, value);
        if (index == listTokensOnSale.length) {
            listTokensOnSale.push(value);
        }
    }

    function _removeFromArray(uint256 value) private {
        uint256 index = _find(listTokensOnSale, value);
        if (index < listTokensOnSale.length) {
            listTokensOnSale[index] = listTokensOnSale[listTokensOnSale.length - 1];
            listTokensOnSale.pop();
        }
    }

    function _find(uint256[] storage list, uint256 value) private view returns (uint256) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                return i;
            }
        }
        return list.length;
    }

    /* -------------------------------------------------------------------------- */
    /*                      DESACTIVAMOS las transferencias nativas               */
    /* -------------------------------------------------------------------------- */

    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
        revert("Not Allowed");
    }

    /* -------------------------------------------------------------------------- */
    /*                            SOLIDITY COMPLIANCE                              */
    /* -------------------------------------------------------------------------- */

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
