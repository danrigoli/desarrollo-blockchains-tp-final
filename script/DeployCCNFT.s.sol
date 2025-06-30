// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CCNFT}  from "../src/CCNFT.sol";

/**
 * @dev Script de despliegue para CCNFT adaptado al nuevo constructor:
 *      CCNFT(string name_, string symbol_, address fundsToken_, address fundsCollector_, address feesCollector_)
 *
 * Variables de entorno requeridas (añádelas a tu `.env` o exporta antes de correr):
 *   NAME                Nombre de la colección  – p.ej. "CoolCourse NFT"
 *   SYMBOL              Símbolo                  – p.ej. "CCNFT"
 *   ADDRESS_BUSD        Dirección del token ERC‑20 con el que se paga (BUSD)
 *   FUNDS_COLLECTOR     Wallet que recibe el importe neto de cada compra
 *   FEES_COLLECTOR      Wallet que recibe las comisiones de buy()/trade()
 *
 * Variables opcionales (se setean tras desplegar):
 *   BUY_FEE             Tarifa de compra  (basis points, 250 = 2.5 %)
 *   TRADE_FEE           Tarifa de trade   (basis points)
 *   MAX_VALUE_TO_RAISE  Máximo a recaudar (wei del ERC‑20)
 *   MAX_BATCH_COUNT     Límite para bucles (uint16)
 */
contract DeployCCNFT is Script {
    function run() external returns (CCNFT nft) {
        /* ------------------------------------------------------------------ */
        /*                       1. Obtenemos las variables                     */
        /* ------------------------------------------------------------------ */
        string  memory name_   = vm.envString("NAME");
        string  memory symbol_ = vm.envString("SYMBOL");

        address fundsToken_     = vm.envAddress("ADDRESS_BUSD");
        address fundsCollector_ = vm.envAddress("FUNDS_COLLECTOR");
        address feesCollector_  = vm.envAddress("FEES_COLLECTOR");

        /* ------------------------------------------------------------------ */
        /*                       2. Despliegue y configuración                  */
        /* ------------------------------------------------------------------ */
        vm.startBroadcast();

        nft = new CCNFT(name_, symbol_, fundsToken_, fundsCollector_, feesCollector_);

        // ajustes opcionales si las vars existen
        if (vm.envOr("BUY_FEE", uint256(0)) > 0) {
            nft.setBuyFee(uint16(vm.envUint("BUY_FEE")));
        }
        if (vm.envOr("TRADE_FEE", uint256(0)) > 0) {
            nft.setTradeFee(uint16(vm.envUint("TRADE_FEE")));
        }
        if (vm.envOr("MAX_VALUE_TO_RAISE", uint256(0)) > 0) {
            nft.setMaxValueToRaise(vm.envUint("MAX_VALUE_TO_RAISE"));
        }
        if (vm.envOr("MAX_BATCH_COUNT", uint256(0)) > 0) {
            nft.setMaxBatchCount(uint16(vm.envUint("MAX_BATCH_COUNT")));
        }

        vm.stopBroadcast();
    }
}
