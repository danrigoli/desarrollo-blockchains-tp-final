// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2 as console} from "forge-std/Script.sol";
import {CCNFT} from "../src/CCNFT.sol";

/**
 * Interactions.s.sol ─ ahora contiene **cuatro** scripts independientes, uno
 * por acción del flujo del marketplace.  Cada script se invoca con “forge
 * script script/Interactions.s.sol:<ContractName> …”.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 *   Contract         Acción              Env vars requeridas (además de las
 *                                        comunes ADDRESS_CCNFT, RPC, KEY)
 * ─────────────────────────────────────────────────────────────────────────────
 *   BuyNFT           buy()               VALUE  · AMOUNT  · TOKEN_URI
 *   PutOnSaleNFT     putOnSale()         TOKEN_ID · PRICE
 *   TradeNFT         trade()             TOKEN_ID
 *   ClaimNFT         claim()             TOKEN_IDS (coma‑separado)
 * ─────────────────────────────────────────────────────────────────────────────
 */

// ---------------------------------------------------------------------------
//  BUY
// ---------------------------------------------------------------------------
contract BuyNFT is Script {
    function run() external {
        CCNFT ccnft = CCNFT(vm.envAddress("ADDRESS_CCNFT"));
        uint256 value = vm.envUint("VALUE");
        uint16 amount = uint16(vm.envUint("AMOUNT"));

        vm.startBroadcast();
        ccnft.buy(value, amount);
        vm.stopBroadcast();
    }
}

// ---------------------------------------------------------------------------
//  PUT ON SALE
// ---------------------------------------------------------------------------
contract PutOnSaleNFT is Script {
    function run() external {
        CCNFT ccnft = CCNFT(vm.envAddress("ADDRESS_CCNFT"));
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint256 price = vm.envUint("PRICE");

        vm.startBroadcast();
        ccnft.putOnSale(tokenId, price);
        vm.stopBroadcast();
    }
}

// ---------------------------------------------------------------------------
//  TRADE
// ---------------------------------------------------------------------------
contract TradeNFT is Script {
    function run() external {
        CCNFT ccnft = CCNFT(vm.envAddress("ADDRESS_CCNFT"));
        uint256 tokenId = vm.envUint("TOKEN_ID");

        vm.startBroadcast();
        ccnft.trade(tokenId);
        vm.stopBroadcast();
    }
}

// ---------------------------------------------------------------------------
//  CLAIM
// ---------------------------------------------------------------------------
contract ClaimNFT is Script {
    function run() external {
        CCNFT ccnft = CCNFT(vm.envAddress("ADDRESS_CCNFT"));
        string memory raw = vm.envString("TOKEN_IDS"); // "1,2,5"
        string[] memory parts = vm.split(raw, ",");
        uint256[] memory ids = new uint256[](parts.length);
        for (uint256 i = 0; i < parts.length; i++) {
            ids[i] = vm.parseUint(parts[i]);
        }

        vm.startBroadcast();
        ccnft.claim(ids);
        vm.stopBroadcast();
    }
}
