package systemcontracts

import (
	"encoding/hex"
	"fmt"
	"github.com/DogeProtocol/dp/accounts/abi"
	"github.com/DogeProtocol/dp/common"
	"github.com/DogeProtocol/dp/core/state"
	"github.com/DogeProtocol/dp/log"
	"strings"
)

const STAKING_CONTRACT = "0x0000000000000000000000000000000000001000"

//var STAKING_CONTRACT = os.Getenv("STAKING_CONTRACT_ADDRESS")

const PROOF_OF_STAKE_STAKING_CONTRACT_BLOCK_NUMBER = 1

var (
	stakingContract    = STAKING_CONTRACT
	stakingContractABI = STAKING_ABI
	stakingContractBIN = STAKING_BIN

	systemContracts      []string
	SystemContractsData  = make(map[string]*Contracts)
	systemContractVerify map[common.Address]bool
)

type Contracts struct {
	ContractAddressString string    `json:"ContractAddressString"`
	Contracts             *Contract `json:"Contracts"`
}

type Contract struct {
	ContractAddress common.Address `json:"ContractAddress"`
	ABI             string         `json:"ABI"`
	BIN             string         `json:"BIN"`
	Methods         *Method        `json:"Methods"`
	CallerAddress   common.Address `json:"CallerAddress"`
}

type Method struct {
	Deposits   *Deposit   `json:"Deposits"`
	Validators *Validator `json:"Validators"`
}

type Deposit struct {
	GetDepositCount        string `json:"GetDepositCount"`
	GetTotalDepositBalance string `json:"GetTotalDepositBalance"`
}

type Validator struct {
	GetDepositBalanceOf string `json:"GetDepositBalanceOf"`
	ListValidator       string `json:"listValidator"`
	GetDepositor        string `json:"GetDepositor"`
}

var (
	methods_collection = &Method{
		Deposits: &Deposit{
			GetDepositCount:        "depositCount",
			GetTotalDepositBalance: "totalDepositBalance",
		},
		Validators: &Validator{
			GetDepositBalanceOf: "depositBalanceOf",
			ListValidator:       "listValidator",
			GetDepositor:        "getDepositor",
		},
	}
)

func init() {
	if len(systemContracts) > 0 {
		return
	}
	systemContracts = []string{
		stakingContract,
	}

	SystemContractsData[stakingContract] = &Contracts{
		ContractAddressString: stakingContract,
		Contracts: &Contract{
			ContractAddress: common.HexToAddress(stakingContract),
			ABI:             stakingContractABI,
			BIN:             stakingContractBIN,
			Methods:         methods_collection,
		},
	}

	systemContractVerify = map[common.Address]bool{
		common.HexToAddress(stakingContract): true,
	}
}

func GetContracts() []string {
	return systemContracts
}

func GetContract_Data(contract string) *Contract {
	return SystemContractsData[contract].Contracts
}

func GetContractVerify(address common.Address) bool {
	return systemContractVerify[address]
}

func IsStakingContract() error {
	if len(stakingContract) < 40 {
		return fmt.Errorf("Staking contractor is not found")
	}
	return nil
}

func GetStakingContract_Address_String() string {
	return SystemContractsData[stakingContract].ContractAddressString
}

func GetStakingContract_Address() common.Address {
	return SystemContractsData[stakingContract].Contracts.ContractAddress
}

func GetStakingContract_ABI() (abi.ABI, error) {
	s := SystemContractsData[stakingContract].Contracts.ABI
	abi, err := abi.JSON(strings.NewReader(s))
	return abi, err
}

// Validators method

func GetContract_Method_ListValidator() string {
	return SystemContractsData[stakingContract].Contracts.Methods.Validators.ListValidator
}

func GetContract_Method_GetDepositor() string {
	return SystemContractsData[stakingContract].Contracts.Methods.Validators.GetDepositor
}

func IsStakingContractCreated(currentBlockNumber uint64) bool {
	if currentBlockNumber > PROOF_OF_STAKE_STAKING_CONTRACT_BLOCK_NUMBER {
		return true
	}

	return false
}

func shouldCreateContract(currentBlockNumber uint64, contractAddress string) bool {
	if strings.Compare(contractAddress, STAKING_CONTRACT) == 0 && currentBlockNumber == PROOF_OF_STAKE_STAKING_CONTRACT_BLOCK_NUMBER {
		return true
	}

	return false
}

func CreateGenesisContracts(statedb *state.StateDB) {
	for _, contract := range SystemContractsData {
		log.Info("Creating system contract", contract.Contracts.ContractAddress)

		newContractCode, err := hex.DecodeString(strings.TrimPrefix(contract.Contracts.BIN, "0x"))
		fmt.Println("CreateGenesisContracts : ", "contract", contract.Contracts.ContractAddress, "len", len(newContractCode))
		if err != nil {
			panic(fmt.Errorf("failed to decode new contract code: %s", err.Error()))
		}
		statedb.CreateAccount(contract.Contracts.ContractAddress)
		statedb.SetCode(contract.Contracts.ContractAddress, newContractCode)
		if err != nil {
			fmt.Println("CreateGenesisContracts error", "error", err)
		} else {
			hash, err := statedb.Commit(false)
			if err != nil {
				fmt.Println("CreateGenesisContracts commit2", hash, err)
			} else {
				fmt.Println("CreateGenesisContracts commit3", hash)
			}

			code := statedb.GetCode(contract.Contracts.ContractAddress)
			if code == nil || len(code) == 0 {
				log.Info("CreateGenesisContracts contract code is nil")
			} else {
				log.Info("CreateGenesisContracts code is not nil", "len", len(code))
			}

			fmt.Println("CreateGenesisContracts ok")
		}

	}
}

func (sf Contract) Address() common.Address {
	return sf.CallerAddress
}