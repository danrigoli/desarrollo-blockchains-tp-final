# -----------------------------------------------------------------------------
#  Cargar variables de entorno (.env) y exportarlas para los shells que invoca
#  Make.  Rellena .env a partir de .env.example.
# -----------------------------------------------------------------------------
include .env
export

# -----------------------------------------------------------------------------
#  Flags comunes para todos los scripts Forge que se transmiten a Sepolia.
# -----------------------------------------------------------------------------
RPC_FLAGS = --rpc-url $(SEPOLIA_RPC_URL) \
            --private-key $(PRIVATE_KEY)  \
            --broadcast -vvvv

RPC_FLAGS_BUYER = --rpc-url $(SEPOLIA_RPC_URL) \
						--private-key $(PRIVATE_KEY_BUYER)  \
						--broadcast -vvvv

# -----------------------------------------------------------------------------
#  Targets básicos de Foundry --------------------------------------------------
# -----------------------------------------------------------------------------
install:               ## Instala dependencias (forge install)
	@forge install

build:                 ## Compila (forge build)
	@forge build

test:                  ## Ejecuta pruebas (forge test -vv)
	@forge test -vv

# -----------------------------------------------------------------------------
#  Despliegue de contratos base -----------------------------------------------
# -----------------------------------------------------------------------------
deploy-busd:           ## Despliega el token BUSD en Sepolia
	@forge script script/DeployBUSD.s.sol:DeployBUSD $(RPC_FLAGS)

deploy-ccnft:          ## Despliega CCNFT (requiere ADDRESS_BUSD en .env)
	@forge script script/DeployCCNFT.s.sol:DeployCCNFT $(RPC_FLAGS)

# -----------------------------------------------------------------------------
#  Acciones Marketplace vía los cuatro sub‑scripts de Interactions.s.sol
#  Ejemplos de uso:
#     make buy VALUE=100e18 AMOUNT=1 TOKEN_URI=ipfs://...
#     make put-on-sale TOKEN_ID=3 PRICE=150e18
#     make trade TOKEN_ID=3
#     make claim TOKEN_IDS=1,2,3
# -----------------------------------------------------------------------------

buy:                    ## buy(value, amount, uri)
	@ADDRESS_CCNFT=$(ADDRESS_CCNFT) \
	 VALUE=$(VALUE)           \
	 AMOUNT=$(AMOUNT)         \
	 TOKEN_URI=$(TOKEN_URI)   \
	 forge script script/Interactions.s.sol:BuyNFT $(RPC_FLAGS)

put-on-sale:            ## putOnSale(tokenId, price)
	@ADDRESS_CCNFT=$(ADDRESS_CCNFT) \
	 TOKEN_ID=$(TOKEN_ID)     \
	 PRICE=$(PRICE)           \
	 forge script script/Interactions.s.sol:PutOnSaleNFT $(RPC_FLAGS)

trade:                  ## trade(tokenId)
	@ADDRESS_CCNFT=$(ADDRESS_CCNFT) \
	 TOKEN_ID=$(TOKEN_ID)     \
	 forge script script/Interactions.s.sol:TradeNFT $(RPC_FLAGS_BUYER)

claim:                  ## claim(tokenIds[])
	@ADDRESS_CCNFT=$(ADDRESS_CCNFT) \
	 TOKEN_IDS=$(TOKEN_IDS)   \
	 forge script script/Interactions.s.sol:ClaimNFT $(RPC_FLAGS)

.PHONY: install build test deploy-busd deploy-ccnft mint buy put-on-sale trade claim
