# Ejemplos de uso de los comandos de make para el contrato CCNFT

# Aprobar el contrato CCNFT para gastar BUSD
cast send $ADDRESS_BUSD \
  "approve(address,uint256)" \
  $ADDRESS_CCNFT\
  100000000000000000000000000000000 \
  --private-key $PRIVATE_KEY_FUNDS \
  --rpc-url     $SEPOLIA_RPC_URL

# Aprobar el contrato CCNFT para gastar BUSD desde la cuenta del owner
cast send $ADDRESS_BUSD \
  "approve(address,uint256)" \
  $ADDRESS_CCNFT\
  100000000000000000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# Para la cuenta del comprador
cast send $ADDRESS_BUSD \ 
  "approve(address,uint256)" \
  $ADDRESS_CCNFT\
  100000000000000000000000000000000 \
  --private-key $PRIVATE_KEY_BUYER \
  --rpc-url $SEPOLIA_RPC_URL


# Añadir valores válidos al contrato CCNFT
cast send $ADDRESS_CCNFT "addValidValues(uint256)" $VALUE \
--private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL


# Mintar un NFT
make buy \
  ADDRESS_CCNFT=$ADDRESS_CCNFT \
  VALUE=$VALUE \
  AMOUNT=2


# Ponerlo en venta
make put-on-sale ADDRESS_CCNFT=$ADDRESS_CCNFT TOKEN_ID=1 PRICE=150e18

# Comprar ese NFT desde otra cuenta
make trade ADDRESS_CCNFT=$ADDRESS_CCNFT TOKEN_ID=1

# Reclamar y quemar varios (owner)
make claim ADDRESS_CCNFT=$ADDRESS_CCNFT TOKEN_IDS=0