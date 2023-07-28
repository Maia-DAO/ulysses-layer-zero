// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {LibString} from "solady/utils/LibString.sol";

import {Test, Vm} from "forge-std/Test.sol";

import {console2} from "forge-std/console2.sol";

import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";

abstract contract LzForkTest is Test {
    using SafeCastLib for uint256;
    using LibString for string;

    /////////////////////////////////
    //         Fork Chains         //
    /////////////////////////////////

    // Relevant information for a fork chain
    struct ForkChain {
        uint256 chainId;
        uint16 lzChainId;
        address lzEndpoint;
    }

    // forkChains is a list of all fork layer zero ChainIds
    uint16[] public lzChainIds;

    // chainIdToLzChainId is a mapping of production chainIds to layer zero ChainIds
    mapping(uint256 chainId => uint16 lzChainId) public chainIdToLzChainId;

    // forkChainMap is a mapping of layer zero ChainIds to fork chain state
    mapping(uint16 lzChainId => ForkChain chainInfo) public forkChains;

    // forkChainIds is a list of all fork chainIds
    mapping(uint16 lzChainId => uint256 chainId) public forkChainIds;

    /////////////////////////////////
    //          Packets            //
    /////////////////////////////////

    // Packet event hash constant
    bytes32 constant PACKET_EVENT_HASH = keccak256("Packet(bytes)");

    // RelayerParams event hash constant
    bytes32 constant RELAYER_PARAMS_EVENT_HASH = keccak256("RelayerParams(bytes,uint16)");

    // Execution status of a packet
    enum ExecutionStatus {
        None,
        Pending,
        Executed
    }

    // Relevant information for a fork chain
    struct Packet {
        uint64 nonce;
        uint16 originLzChainId;
        address originUA;
        uint16 destinationLzChainId;
        address destinationUA;
        bytes payload;
        bytes data;
    }

    // Relayer parameter emitted along packet
    struct RelayerParams {
        bytes adapterParams;
        uint16 outboundProofType;
    }

    // Relayer Adapter Params
    struct AdapterParams {
        uint16 version;
        RelayerParams relayerParams;
    }

    // Packet data emitted from a given chain
    mapping(uint16 fromChain => Packet[] outgoingPackets) public packetsFromChain;

    // Packet data emitted to a given chain
    mapping(uint16 toChain => Packet[] incomingPackets) public packetsToChain;

    // Packet execution status
    mapping(bytes32 packetHash => ExecutionStatus status) public packetExecutionStatus;

    // Packet adapter params mapping
    mapping(bytes32 packetHash => AdapterParams adapterParams) public packetAdapterParams;

    /////////////////////////////////
    //           Views             //
    /////////////////////////////////

    /// @notice getNextPacket returns the next packet from a layer zero chain.
    /// @param lzChainId the layer zero chain id of the packet
    function getNextPacket(uint16 lzChainId) public view returns (Packet memory) {
        return packetsFromChain[lzChainId][0];
    }

    /// @notice getIncomingPackets returns the incoming packets for a layer zero chain.
    /// @param lzChainId the layer zero chain id of the packet
    function getIncomingPackets(uint16 lzChainId) public view returns (Packet[] memory) {
        return packetsToChain[lzChainId];
    }

    /// @notice getOutgoingPackets returns the outgoing packets for a layer zero chain.
    /// @param lzChainId the layer zero chain id of the packet
    function getOutgoingPackets(uint16 lzChainId) public view returns (Packet[] memory) {
        return packetsFromChain[lzChainId];
    }

    /////////////////////////////////
    //           SetUp             //
    /////////////////////////////////

    /// @notice setUp is called by the test runner before each test, setting up different fork chains.
    function setUp() public virtual {
        // Set up default fork chains
        setUpDefaultLzChains();

        // Start the recorder necessary for packet tracking
        vm.recordLogs();
    }

    /////////////////////////////////
    //       Set Up Helpers        //
    /////////////////////////////////

    /// @notice setUpDefaultLzChains sets up the default fork chains for testing.
    function setUpDefaultLzChains() internal {
        // Access variables from .env file via vm.envString("varname")
        // Change RPCs using your .env file
        // Override setUp() if you don't want to set up Default Layer Zero Chains

        console2.log("Setting up default fork chains...");

        // addChain(
        //     ForkChain(1, 101, 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675),
        //     string.concat(vm.envString("MAINNET_RPC_URL"), vm.envString("INFURA_API_KEY"))
        // );

        addChain(
            ForkChain(43114, 106, 0x3c2269811836af69497E5F486A85D7316753cf62),
            string.concat(vm.envString("AVAX_RPC_URL"), vm.envString("INFURA_API_KEY"))
        );

        // addChain(
        //     ForkChain(137, 109, 0x3c2269811836af69497E5F486A85D7316753cf62),
        //     string.concat(vm.envString("POLYGON_RPC_URL"), vm.envString("INFURA_API_KEY"))
        // );

        addChain(
            ForkChain(42161, 110, 0x3c2269811836af69497E5F486A85D7316753cf62),
            string.concat(vm.envString("ARBITRUM_RPC_URL"), vm.envString("INFURA_API_KEY"))
        );

        // addChain(
        //     ForkChain(10, 111, 0x3c2269811836af69497E5F486A85D7316753cf62),
        //     string.concat(vm.envString("OPTIMISM_RPC_URL"), vm.envString("INFURA_API_KEY"))
        // );

        // addChain(
        //     ForkChain(42220, 125, 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9),
        //     string.concat(vm.envString("CELO_RPC_URL"), vm.envString("INFURA_API_KEY"))
        // );

        // addChain(ForkChain(56, 102, 0x3c2269811836af69497E5F486A85D7316753cf62), vm.envString("BNB_RPC_URL"));

        addChain(ForkChain(250, 112, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7), vm.envString("FANTOM_RPC_URL"));

        // addChain(ForkChain(53935, 115, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("DFK_RPC_URL")));

        // addChain(
        //     ForkChain(1666600001, 116, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("HARMONY_RPC_URL"))
        // );

        // addChain(ForkChain(1284, 126, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("MOONBEAM_RPC_URL")));

        // addChain(ForkChain(122, 127, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("FUSE_RPC_URL")));

        // addChain(ForkChain(100, 145, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("GNOSIS_RPC_URL")));

        // addChain(ForkChain(8217, 150, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("KLAYTN_RPC_URL")));

        // addChain(ForkChain(1088, 151, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("METIS_RPC_URL")));

        // addChain(ForkChain(66, 155, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("OKT_RPC_URL")));

        // addChain(
        //     ForkChain(1101, 158, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("POLYGONZKEVM_RPC_URL"))
        // );

        // addChain(ForkChain(7700, 159, 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4), (vm.envString("CANTO_RPC_URL")));

        // addChain(ForkChain(324, 165, 0x9b896c0e23220469C7AE69cb4BbAE391eAa4C8da), (vm.envString("ZKSYNCERA_RPC_URL")));

        // addChain(ForkChain(1285, 167, 0x7004396C99D5690da76A7C59057C5f3A53e01704), (vm.envString("MOONRIVER_RPC_URL")));

        // addChain(ForkChain(1559, 173, 0x2D61DCDD36F10b22176E0433B86F74567d529aAa), (vm.envString("TENET_RPC_URL")));

        // addChain(
        //     ForkChain(42170, 175, 0x4EE2F9B7cf3A68966c370F3eb2C16613d3235245), (vm.envString("ARBITRUMNOVA_RPC_URL"))
        // );

        // addChain(ForkChain(82, 176, 0xa3a8e19253Ab400acDac1cB0eA36B88664D8DedF), (vm.envString("METERIO_RPC_URL")));

        // addChain(
        //     ForkChain(11155111, 161, 0x7cacBe439EaD55fa1c22790330b12835c6884a91), (vm.envString("SEPOLIA_RPC_URL"))
        // );
    }

    /// @notice addChain adds a new fork chain to the forkChains list.
    /// @param newChain the new chain to add.
    /// @param chainURL the chain's RPC URL.
    function addChain(ForkChain memory newChain, string memory chainURL) public {
        //Verify Addition
        if (bytes(chainURL).length == 0) return;
        //Create Fork Chain
        uint256 forkChainId = vm.createFork(chainURL);
        //Save new lzChainId
        lzChainIds.push(newChain.lzChainId);
        //Add chain Id conversion
        chainIdToLzChainId[newChain.chainId] = newChain.lzChainId;
        //Save new forkChain
        forkChains[newChain.lzChainId] = newChain;
        //Save new forkChainId
        forkChainIds[newChain.lzChainId] = forkChainId;
    }

    /// @notice addChain adds a new fork chain at a given blockNumber to the forkChains list.
    /// @param newChain the new chain to add.
    /// @param chainURL the chain's RPC URL.
    /// @param blockNumber the block number to fork at.
    function addChain(ForkChain memory newChain, string memory chainURL, uint256 blockNumber) public {
        //Verify Addition
        if (bytes(chainURL).length > 0) return;
        //Create Fork Chain
        uint256 forkChainId = vm.createFork(chainURL, blockNumber);
        //Save new lzChainId
        lzChainIds.push(newChain.lzChainId);
        //Add chain Id conversion
        chainIdToLzChainId[newChain.chainId] = newChain.lzChainId;
        //Save new forkChain
        forkChains[newChain.lzChainId] = newChain;
        //Save new forkChainId
        forkChainIds[newChain.lzChainId] = forkChainId;
    }

    /////////////////////////////////
    //        Chain Helpers        //
    /////////////////////////////////

    /// @notice switchToChain switches the current chain to the given chain, executing pending Lz packets and updating Lz packets state.
    /// @param chainId the chain to switch to.
    function switchToChain(uint256 chainId) public {
        console2.log("Switching to chain", chainId);
        vm.selectFork(forkChainIds[chainIdToLzChainId[chainId]]);
        console2.log("Selected fork", forkChainIds[chainIdToLzChainId[chainId]]);
        updatePackets("", updateAll);
        console2.log("Updated Packets", chainIdToLzChainId[chainId]);
        executePackets(chainId.toUint16());
        console2.log("Executed packets on chain", chainId);
    }

    /// @notice switchToChainWithoutExecutePending switches the current chain to the given chain without executing pending packets.
    /// @param chainId the chain to switch to.
    function switchToChainWithoutExecutePending(uint256 chainId) public {
        vm.selectFork(forkChainIds[chainIdToLzChainId[chainId]]);
        updatePackets("", updateAll);
    }

    /// @notice switchToChainWithoutPacketUpdate switches the current chain to the given chain without updating layer zero packets.
    /// @param chainId the chain to switch to.
    function switchToChainWithoutPacketUpdate(uint256 chainId) public {
        vm.selectFork(forkChainIds[chainIdToLzChainId[chainId]]);
        executePackets(chainIdToLzChainId[chainId]);
    }

    /// @notice switchToChainWithoutExecutePendingOrPacketUpdate switches the current chain to the given chain without executing pending packets or updating layer zero packets.
    /// @param chainId the chain to switch to.
    function switchToChainWithoutExecutePendingOrPacketUpdate(uint256 chainId) public {
        vm.selectFork(forkChainIds[chainIdToLzChainId[chainId]]);
    }

    /////////////////////////////////
    //       Lz Chain Helpers      //
    /////////////////////////////////

    /// @notice switchToLzChain switches the current chain to the given chain.
    /// @param lzChainId the chain to switch to.
    function switchToLzChain(uint16 lzChainId) public {
        vm.selectFork(forkChainIds[lzChainId]);
        updatePackets("", updateAll);
        executePackets(lzChainId);
    }

    /// @notice switchToLzChainWithoutExecutePending switches the current chain to the given chain without executing pending packets.
    /// @param lzChainId the chain to switch to.
    function switchToLzChainWithoutExecutePending(uint16 lzChainId) public {
        vm.selectFork(forkChainIds[lzChainId]);
        updatePackets("", updateAll);
    }

    /// @notice switchToLzChainWithoutPacketUpdate switches the current chain to the given chain without updating layer zero packets.
    /// @param lzChainId the chain to switch to.
    function switchToLzChainWithoutPacketUpdate(uint16 lzChainId) public {
        vm.selectFork(forkChainIds[lzChainId]);
        executePackets(lzChainId);
    }

    /// @notice switchToLzChainWithoutExecutePendingOrPacketUpdate switches the current chain to the given chain without executing pending packets or updating layer zero packets.
    /// @param lzChainId the chain to switch to.
    function switchToLzChainWithoutExecutePendingOrPacketUpdate(uint16 lzChainId) public {
        vm.selectFork(forkChainIds[lzChainId]);
    }

    /////////////////////////////////
    //      Update Lz Packets      //
    /////////////////////////////////

    /// @notice updatePackets updates Lz packets
    /// @param data the data to be passed to the skipPacket function
    /// @param skipPacket the function to be executed upon skipping a packet
    function updatePackets(
        bytes memory data,
        function(bytes memory, Packet memory) internal pure returns (bool) skipPacket
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        console2.log("Events caugth:", entries.length);

        for (uint256 i = 0; i < entries.length; i++) {
            // Look for 'RelayerParams' events
            if (entries[i].topics[0] == RELAYER_PARAMS_EVENT_HASH) {
                //// 1. Decode Adapter Params

                // Adapter Params Vars
                RelayerParams memory relayerParams;
                uint16 relayerAdapterParamsVersion;

                // Get Adapter Params
                (bytes memory adapterParams, uint16 outboundProofType) = abi.decode(entries[i].data, (bytes, uint16));

                relayerParams = RelayerParams(adapterParams, outboundProofType);

                //// 2. Increment to next event 'Packet'
                i += 2;

                //// 3. Decode new packet instance
                (Packet memory packet, uint16 originLzChainId, uint16 destinationLzChainId) =
                    decodePacket(entries[i].data);

                //// 4. Get packet hash
                bytes32 packetHash = encodePacket(packet);

                //// 5. Check if packet has already been registered
                if (packetExecutionStatus[packetHash] != ExecutionStatus.None) {
                    continue;
                }
                //// 6. Update Packet storage

                // Update Packet Execution Status
                packetExecutionStatus[packetHash] = ExecutionStatus.Pending;

                // Update Outgoing Packets
                packetsFromChain[originLzChainId].push(packet);

                // Update Incoming Packets
                packetsToChain[destinationLzChainId].push(packet);
                console2.log("Packet added to chain", destinationLzChainId);

                // Attach Packet to Adapter Params
                packetAdapterParams[packetHash] = AdapterParams(relayerAdapterParamsVersion, relayerParams);
            }
        }
    }

    /// @notice updateAll updates all packets
    function updateAll(bytes memory, Packet memory) internal pure returns (bool) {
        return false;
    }

    /// @notice updateOrigin updates packets from a layer zero chain
    /// @param data the data to be passed to the updateOrigin function
    /// @param packet the packet to be updated
    function updateOrigin(bytes memory data, Packet memory packet) internal pure returns (bool) {
        return abi.decode(data, (uint16)) == packet.originLzChainId;
    }

    /// @notice updateDestination updates packets to a layer zero chain
    /// @param data the data to be passed to the updateDestination function
    /// @param packet the packet to be updated
    function updateDestination(bytes memory data, Packet memory packet) internal pure returns (bool) {
        return abi.decode(data, (uint16)) == packet.destinationLzChainId;
    }

    /// @notice updatePackets updates the packets for all layer zero chains. NOTE: CURRENTLY ONLY EVM COMPATIBLE CHAINS ALLOWED DUE TO ADDRESS SIZE LIMITATIONS.
    function updateAllPackets() public {
        updatePackets("", updateAll);
    }

    /////////////////////////////////
    //      Execute Lz Packets     //
    /////////////////////////////////

    /// @notice executePackets executes all pending packets for a layer zero chain.
    function executePackets(uint16 lzChainId) public {
        // Get incoming packets
        Packet[] storage incoming = packetsToChain[lzChainId];
        console2.log("Packets:", incoming.length);
            console2.log(lzChainId);

        // Read packets
        for (uint256 i = 0; i < incoming.length; i++) {
            console2.log("Packet:", i);
            console2.log("Packet:", incoming[i].originLzChainId);
            // Get packet
            Packet memory packet = incoming[i];

            // Execute packet
            executePacket(packet);

            // Update packet execution status
            packetExecutionStatus[encodePacket(packet)] = ExecutionStatus.Executed;
        }
    }

    /// @notice executeNextPacket executes the next pending packet for a layer zero chain.
    function executeNextPacket(uint16 lzChainId) public {
        // Get next incoming packet
        Packet memory incoming = packetsToChain[lzChainId][0];

        // Execute packet
        executePacket(incoming);
    }

    /// @notice executePacket executes a packet for a layer zero chain.
    function executePacket(Packet memory packet) public {
        // Get packet hash
        bytes32 packetHash = encodePacket(packet);

        // Check if packet has already been executed
        if (packetExecutionStatus[packetHash] == ExecutionStatus.Executed) {
            return;
        }

        // Get Receiving Endpoint in destination chain
        address receivingEndpoint = forkChains[packet.originLzChainId].lzEndpoint;

        //Get Application Config for destination User Application
        address receivingLibrary = ILayerZeroEndpoint(receivingEndpoint).getReceiveLibraryAddress(packet.destinationUA);

        //Get adapter params for packet
        AdapterParams memory adapterParams = packetAdapterParams[packetHash];

        //Get gas limit and execute relayer adapter params
        uint256 gasLimit = handleAdapterParams(adapterParams);

        // Acquire gas, Prank into Library and Mock LayerZeroEndpoint.receivePayload call
        vm.prank(receivingLibrary);
        ILayerZeroEndpoint(receivingEndpoint).receivePayload(
            packet.originLzChainId,
            abi.encodePacked(packet.destinationUA, packet.originUA),
            packet.destinationUA,
            packet.nonce,
            gasLimit,
            packet.payload
        );
    }

    /////////////////////////////////
    //          Lz Handlers        //
    /////////////////////////////////

    function handleAdapterParams(AdapterParams memory params) internal returns (uint256 gasLimit) {
        // Save adapter params to memory
        bytes memory adapterParams = params.relayerParams.adapterParams;
        console2.log("Adapter Params:", adapterParams.length);
        console2.logBytes(adapterParams);

        // Check if adapter params are empty
        if (adapterParams.length > 0) {
            // Get adapter Params Version
            uint256 version;
            assembly ("memory-safe") {
                // Load 32 bytes from encodedPacket + mask out remaining 32 - 2 = 30 bytes
                version := shr(240, and(mload(adapterParams), 0xffff000000000000000000000000000000000000000000000000000000000000))
            }
        console2.log("Version:", version);
            // Serve request according to relayerVersion
            if (version == 1) {
                assembly ("memory-safe") {
                    // Load 32 bytes from adapterParams offsetting the first 2 bytes
                    gasLimit := mload(add(adapterParams, 2))
                }
            } else if (version == 2) {
                uint256 nativeForDst;
                address addressOnDst;
                assembly ("memory-safe") {
                    // Load 32 bytes from adapterParams offsetting the first 2 bytes
                    gasLimit := mload(add(adapterParams, 2))

                    // Load 32 bytes from adapterParams offsetting the first 34 bytes
                    nativeForDst := mload(add(adapterParams, 34))

                    // Load 32 bytes from adapterParams + mask out remaining 32 - 20 = 12 bytes offsetting the first 66 bytes
                    addressOnDst :=
                        shr(96, and(
                            mload(add(adapterParams, 66)),
                            0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000
                        ))
                }
                // Send gas airdrop
                deal(address(this), nativeForDst);
                addressOnDst.call{value: nativeForDst}("");

                console2.log("Gas Limit:", gasLimit);
            }
        } else {
            gasLimit = 200_000;
        }
    }

    /////////////////////////////////
    //          Lz Helpers         //
    /////////////////////////////////

    /// @notice encodePacket creates a 32 byte long keccak256 hash of Packet
    function encodePacket(Packet memory packet) public returns (bytes32) {
        return keccak256(abi.encode(packet));
    }

    /// @notice encodePacket creates a 32 byte long keccak256 hash of Packet
    function encodePacket(
        uint64 nonce,
        uint16 originLzChainId,
        address originUA,
        uint16 destinationLzChainId,
        address destinationUA,
        bytes memory payload,
        bytes memory data
    ) public returns (bytes32) {
        return
            encodePacket(Packet(nonce, originLzChainId, originUA, destinationLzChainId, destinationUA, payload, data));
    }

    /// @notice decodePacket decodes the encoded packet into a Packet struct
    function decodePacket(bytes memory encodedPacket)
        internal
        returns (
            // pure
            Packet memory packet,
            uint16 originLzChainId,
            uint16 destinationLzChainId
        )
    {
        // Packet Vars
        uint64 nonce;
        address originUA;
        address destinationUA;

        assembly ("memory-safe") {         
            // Load first 32 bytes from encodedPacket + mask out remaining 32 - 8 = 24 bytes
            nonce :=
                shr(192, and(mload(add(encodedPacket, 96)), 0xffffffffffffffff000000000000000000000000000000000000000000000000))

            // Load 32 bytes from encodedPacket + mask out remaining 32 - 2 = 30 bytes
            originLzChainId :=
                shr(
                    240,
                    and(mload(add(add(encodedPacket, 96), 8)), 0xffff000000000000000000000000000000000000000000000000000000000000)
                )

            // Load 32 bytes from encodedPacket + mask out remaining 32 - 20 = 12 bytes
            originUA :=
                shr(
                    96,
                    and(mload(add(add(encodedPacket, 96), 10)), 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000)
                )

            // Load 32 bytes from encodedPacket + mask out remaining 32 - 2 = 30 bytes
            destinationLzChainId :=
                shr(
                    240,
                    and(mload(add(add(encodedPacket, 96), 30)), 0xffff000000000000000000000000000000000000000000000000000000000000)
                )

            // Load 32 bytes from encodedPacket + mask out remaining 32 - 20 = 12 bytes
            destinationUA :=
                shr(
                    96,
                    and(mload(add(add(encodedPacket, 96), 32)), 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000)
                ) // Mask out 32 - 20 bytes
        }

        if (encodedPacket.length > 52) {
            packet = Packet(
                nonce,
                originLzChainId,
                originUA,
                destinationLzChainId,
                destinationUA,
                bytes(string(encodedPacket).slice(52)),
                encodedPacket
            );
        } else {
            packet = Packet(nonce, originLzChainId, originUA, destinationLzChainId, destinationUA, "", encodedPacket);
        }
    }

    /// @notice plantPacket adds to storage a packet from a layer zero chain.
    /// @param packet the packet to be planted
    function plantPacket(Packet memory packet) public {
        // Get packet hash
        bytes32 packetHash = encodePacket(packet);

        // Check if packet has already been registered
        if (packetExecutionStatus[packetHash] != ExecutionStatus.None) {
            return;
        }

        // Update Packet Execution Status
        packetExecutionStatus[packetHash] = ExecutionStatus.Pending;

        // Update Outgoing Packets
        packetsFromChain[packet.originLzChainId].push(packet);

        // Update Incoming Packets
        packetsToChain[packet.destinationLzChainId].push(packet);
    }

    /// @notice plantPacket adds to storage a packet from a layer zero chain.
    /// @param nonce the nonce of the packet
    /// @param originLzChainId the origin layer zero chain id of the packet
    /// @param originUA the origin user address of the packet
    /// @param destinationLzChainId the destination layer zero chain id of the packet
    /// @param destinationUA the destination user address of the packet
    /// @param payload the payload of the packet
    /// @param data the whole data of the packet
    function plantPacket(
        uint64 nonce,
        uint16 originLzChainId,
        address originUA,
        uint16 destinationLzChainId,
        address destinationUA,
        bytes memory payload,
        bytes memory data
    ) public {
        plantPacket(Packet(nonce, originLzChainId, originUA, destinationLzChainId, destinationUA, payload, data));
    }

    /// @notice setPacketExecutionStatus sets the execution status of a packet.
    /// @param packet the packet to be updated
    /// @param status the execution status to be set
    function setPacketExecutionStatus(Packet memory packet, ExecutionStatus status) public {
        packetExecutionStatus[encodePacket(packet)] = status;
    }

    /// @notice setPacketExecutionStatus sets the execution status of a packet.
    /// @param nonce the nonce of the packet
    /// @param originLzChainId the origin layer zero chain id of the packet
    /// @param originUA the origin user address of the packet
    /// @param destinationLzChainId the destination layer zero chain id of the packet
    /// @param destinationUA the destination user address of the packet
    /// @param payload the payload of the packet
    /// @param data the whole data of the packet
    /// @param status the execution status to be set
    function setPacketExecutionStatus(
        uint64 nonce,
        uint16 originLzChainId,
        address originUA,
        uint16 destinationLzChainId,
        address destinationUA,
        bytes memory payload,
        bytes memory data,
        ExecutionStatus status
    ) public {
        setPacketExecutionStatus(
            Packet(nonce, originLzChainId, originUA, destinationLzChainId, destinationUA, payload, data), status
        );
    }
}
