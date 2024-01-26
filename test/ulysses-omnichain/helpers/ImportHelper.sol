//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

//TEST
import {LzForkTest} from "../../test-utils/fork/LzForkTest.t.sol";

import {Ownable, SafeTransferLib} from "solady/Milady.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {ILayerZeroEndpoint, ILayerZeroUserApplicationConfig} from "@omni/interfaces/ILayerZeroEndpoint.sol";
import {IBranchRouter} from "@omni/interfaces/IBranchRouter.sol";

import {IRootPort, RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";
import {BranchPort, IBranchPort} from "@omni/BranchPort.sol";
import {IVirtualAccount, Call, PayableCall, VirtualAccount} from "@omni/VirtualAccount.sol";

import {IRootBridgeAgent, RootBridgeAgent, DepositParams, DepositMultipleParams} from "@omni/RootBridgeAgent.sol";
import {RootBridgeAgentExecutor} from "@omni/RootBridgeAgentExecutor.sol";
import {BranchBridgeAgent, IBranchBridgeAgent} from "@omni/BranchBridgeAgent.sol";
import {BranchBridgeAgentExecutor} from "@omni/BranchBridgeAgentExecutor.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {ArbitrumBaseBranchRouter} from "@omni/ArbitrumBaseBranchRouter.sol";
import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter, OutputParams, OutputMultipleParams} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {CoreBranchRouter} from "@omni/CoreBranchRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hToken} from "@omni/token/ERC20hToken.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {BridgeAgentConstants} from "@omni/interfaces/BridgeAgentConstants.sol";
import {Deposit, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchBridgeAgent.sol";
import {ICoreRootRouter} from "@omni/interfaces/ICoreRootRouter.sol";
import {IRootRouter} from "@omni/interfaces/IRootRouter.sol";
import {Settlement, SettlementInput, GasParams} from "@omni/interfaces/IRootBridgeAgent.sol";

import {AddressCodeSize} from "@omni/lib/AddressCodeSize.sol";
import {DecodeBridgeInMultipleParams} from "@omni/lib/DecodeBridgeInMultipleParams.sol";
import {ReservesRatio} from "@omni/lib/ReservesRatio.sol";

import {ComputeVirtualAccount} from "../mocks/ComputeVirtualAccount.t.sol";
import {Multicall2} from "../mocks/Multicall2.sol";
import {MockPortStrategy} from "../mocks/MockPortStrategy.t.sol";
import {MockRootBridgeAgent} from "../mocks/MockRootBridgeAgent.t.sol";
import {MockBranchBridgeAgent} from "../mocks/MockBranchBridgeAgent.t.sol";
import {WETH9 as WETH} from "../mocks/WETH9.sol";
