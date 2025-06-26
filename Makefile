-include .env

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install openzeppelin/openzeppelin-contracts@v5.0.2 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1
# token contract
deploy-token:
	@forge script script/section-one-erc20/DeployOurToken.s.sol:DeployOurToken --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-token-sepolia:
	@forge script script/section-one-erc20/DeployOurToken.s.sol:DeployOurToken --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify

verify-token:
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x00000000000000000000000000000000000000000000d3c21bcecceda1000000 --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version v0.8.19+commit.7dd6d404 0x089dc24123e0a27d44282a1ccc2fd815989e3300 src/section-one-erc20/OurToken.sol:OurToken

# basic nft
deploy-basic-nft:
	@forge script script/section-two-erc721/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-basic-nft-sepolia:
	@forge script script/section-two-erc721/DeployBasicNft.s.sol:DeployBasicNft --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify

mint-basic-nft:
	@forge script script/section-two-erc721/Interactions.s.sol:MintBasicNft --rpc-url http://127.0.0.1:8545

# Mood nft
deploy-mood-nft:
	@forge script script/section-two-erc721/DeployMoodNft.s.sol:DeployMoodNft --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-mood-nft-sepolia:
	@forge script script/section-two-erc721/DeployMoodNft.s.sol:DeployMoodNft --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify

# Generate Input
generate-input:
	@forge script script/section-five-airdrop/GenerateInput.s.sol:GenerateInput --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY)

# Make merkle
make-merkle:
	@forge script script/section-five-airdrop/MakeMerkle.s.sol:MakeMerkle --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY)
