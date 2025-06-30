// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/BUSD.sol";
import "../src/CCNFT.sol";

/**
 * CCNFT.t.sol  –  Pruebas para el contrato CCNFT.
 *
 * testBuy()               - testSetFundsCollector()
 * testSetFeesCollector()  - testSetProfitToPay()
 * testSetCanBuy()         - testSetCanTrade()
 * testSetCanClaim()       - testSetMaxValueToRaise()
 * testAddValidValues()    - testSetMaxBatchCount()
 * testSetBuyFee()         - testSetTradeFee()
 * testCannotTradeWhenCanTradeIsFalse()
 * testCannotTradeWhenTokenDoesNotExist()
 */
contract CCNFTTest is Test {
    /* ───────────── Actores ───────────── */
    address deployer = address(this); // owner
    address user1 = address(0xA1);
    address user2 = address(0xB2);
    address fundsColl = address(0xF1);
    address feesColl = address(0xF2);

    /* ───────────── Contratos ─────────── */
    BUSD busd;
    CCNFT nft;

    /* ─────────── Parámetros ──────────── */
    uint256 constant VALUE = 100 * 1e18; // 100 BUSD
    uint16 constant AMOUNT = 1;

    /* ───────────── setUp() ───────────── */
    function setUp() public {
        // 1. token de pago
        busd = new BUSD();

        // 2. despliegue NFT
        nft = new CCNFT("CoolCourse NFT", "CCNFT", address(busd), fundsColl, feesColl);

        // 3. configuración inicial
        nft.addValidValues(VALUE);
        nft.setCanBuy(true);
        nft.setMaxBatchCount(10);
        nft.setMaxValueToRaise(1_000_000 * 1e18);

        // 4. dotar user1 con BUSD + allowance
        busd.transfer(user1, 1_000 * 1e18);
        vm.startPrank(user1);
        busd.approve(address(nft), type(uint256).max);
        vm.stopPrank();
    }

    /* ───────────────────────────────────
     *               BUY
     * ──────────────────────────────────*/
    function testBuy() public {
        vm.prank(user1);
        nft.buy(VALUE, AMOUNT);

        // tokenId inicial es 0 (Counters arranca en 0)
        assertEq(nft.ownerOf(0), user1);

        uint256 fee = (VALUE * nft.buyFee()) / 10_000;
        assertEq(busd.balanceOf(feesColl), fee);
        assertEq(busd.balanceOf(fundsColl), VALUE - fee);
    }

    /* ───────────── Setters ───────────── */
    function testSetFundsCollector() public {
        address newAddr = address(0x1234);
        nft.setFundsCollector(newAddr);
        assertEq(nft.fundsCollector(), newAddr);
    }

    function testSetFeesCollector() public {
        address newAddr = address(0x5678);
        nft.setFeesCollector(newAddr);
        assertEq(nft.feesCollector(), newAddr);
    }

    function testSetProfitToPay() public {
        nft.setProfitToPay(500); // 5 %
        assertEq(nft.profitToPay(), 500);
    }

    function testSetCanBuy() public {
        nft.setCanBuy(false);
        assertFalse(nft.canBuy());
        nft.setCanBuy(true);
        assertTrue(nft.canBuy());
    }

    function testSetCanTrade() public {
        nft.setCanTrade(true);
        assertTrue(nft.canTrade());
    }

    function testSetCanClaim() public {
        nft.setCanClaim(true);
        assertTrue(nft.canClaim());
    }

    function testSetMaxValueToRaise() public {
        nft.setMaxValueToRaise(500_000 * 1e18);
        assertEq(nft.maxValueToRaise(), 500_000 * 1e18);
    }

    function testAddValidValues() public {
        uint256 newVal = 50 * 1e18;
        nft.addValidValues(newVal);
        assertTrue(nft.validValues(newVal));
    }

    function testSetMaxBatchCount() public {
        nft.setMaxBatchCount(25);
        assertEq(nft.maxBatchCount(), 25);
    }

    function testSetBuyFee() public {
        nft.setBuyFee(300); // 3 %
        assertEq(nft.buyFee(), 300);
    }

    function testSetTradeFee() public {
        nft.setTradeFee(450); // 4.5 %
        assertEq(nft.tradeFee(), 450);
    }

    /* ──────────── Negativos ──────────── */
    function testCannotTradeWhenCanTradeIsFalse() public {
        vm.prank(user1);
        nft.buy(VALUE, AMOUNT); // crea el token 0

        // canTrade sigue en false ⇒ trade debe revertir con “Token not On Sale”
        vm.prank(user2);
        vm.expectRevert(bytes("Token not On Sale"));
        nft.trade(0);
    }

    function testCannotTradeWhenTokenDoesNotExist() public {
        nft.setCanTrade(true); // activamos trade

        // token 9999 no existe ⇒ revert “Token does not exist”
        vm.prank(user2);
        vm.expectRevert(bytes("Token does not exist"));
        nft.trade(9999);
    }
}
