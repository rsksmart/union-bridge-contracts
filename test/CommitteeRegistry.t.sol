// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    ICommitteeRegistry,
    PendingCommitteeStatus,
    Role,
    CommitteeMember,
    Committee,
    CommunicationData,
    COMMUNICATION_DATA_CHUNKS,
    MemberRegistrationKeys
} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "src/libraries/Constants.sol";
import {SignatureData} from "src/interfaces/ISignatureManager.sol";
import {IPausable} from "src/interfaces/IPausable.sol";

contract CommitteeRegistryTest is Test, HelperContract {
    // Maximum allowed gas for committee creation operations
    // Set to 2M gas, which is ~29% of RSK's block gas limit (6.8M)
    // This ensures committee creation doesn't consume excessive gas while leaving
    // room for other transactions in the block. The specific value is a test constraint
    // chosen to be conservative yet practical based on current implementation costs.
    uint256 constant MAX_GAS_PER_COMMITTEE_CREATION = 2_000_000;

    function setUp() external {
        runTestDeployScript();
        vm.roll(1000);
    }

    function test_applyToStream_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(member, minimumDeposit);

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.applyToStream{value: minimumDeposit}(denomination, role, memberRegistrationKeys, generateDefaultUTXO());
    }

    function test_applyToStream_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();

        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;

        // Act
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        // Assert
        memberRegistry.getMemberPublicKeys(member);
    }

    function test_unsubscribeFromStream_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        // member should have applied to the stream before unsubscribing from it
        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.unsubscribeFromStream(denomination);
    }

    function test_unsubscribeFromStream_Success_UnpausedContract() external {
        // Arrange
        // member should have applied to the stream before unsubscribing from it
        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        pauseAndUnpauseContracts();

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(member, denomination);

        // Act
        vm.prank(member);
        registry.unsubscribeFromStream(denomination);
    }

    function test_restartPendingCommittee_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);
    }

    function test_restartPendingCommittee_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        setup_pendingCommitteeAndExpire();
        Committee memory firstPendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);

        // Act
        registry.restartPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);

        // Assert
        Committee memory secondPendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);
        assertEq(secondPendingCommittee.createdAt, BLOCK_COMMITTEE_3);
        assertEqCommitteeStructure(secondPendingCommittee, firstPendingCommittee);
    }

    function test_createCommittee_Success_PausedContract() external {
        // Arrange
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = new bytes(0);

        pauseContracts();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(committeeId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(peginManager));
        registry.createCommittee(expectedCommittee.streamId);
    }

    function test_depositAggregatedKey_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        bytes memory aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.aggregatedKey = aggregatedKey;
        CommitteeMember memory member = registry.getCommitteeMembers(committeeId)[0];
        address memberAddress = member.memberAddress;

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, aggregatedKey);
    }

    function test_depositAggregatedKey_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();

        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        bytes memory aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.aggregatedKey = aggregatedKey;

        CommitteeMember memory member = registry.getCommitteeMembers(committeeId)[0];
        address memberAddress = member.memberAddress;

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberInfoDeposited(committeeId, memberAddress, aggregatedKey);

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, aggregatedKey);
    }

    function test_depositCommunicationData_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 privKey = uint256(2);
        address member = vm.addr(privKey);

        uint256 expectedCommitteeSize = 1;
        uint256 memberIndex = 0;
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommitteeSize, memberIndex);

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.depositCommunicationData(0, communicationData);
    }

    function test_depositCommunicationData_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();

        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberCommunicationDataDeposited(committeeId, memberAddress, communicationData);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_whitelisterDefaultIsOwner() external view {
        // Act & Assert
        assertEq(registry.whitelister(), registry.owner());
    }

    function test_setWhitelister_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        address newWhitelisterAddress = address(0x123);
        address unauthorizedCaller = address(0x12345);

        // Assert
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorizedCaller));

        // Act
        registry.setWhitelister(newWhitelisterAddress);
    }

    function test_setWhitelister_Success() external {
        // Arrange
        address newWhitelisterAddress = address(0x123);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.WhitelisterUpdated(newWhitelisterAddress);

        // Act
        vm.prank(registry.owner());
        registry.setWhitelister(newWhitelisterAddress);

        // Assert
        assertEq(registry.whitelister(), newWhitelisterAddress);
    }

    function test_setWhitelister_Revert_InvalidZeroAddress() external {
        // Arrange
        address invalidAddress = address(0);
        vm.startPrank(registry.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPausable.InvalidZeroAddress.selector));

        // Act
        registry.setWhitelister(invalidAddress);
    }

    function test_setPendingCommitteeTimeout_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 newCommitteeTimeout = uint256(5);
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PendingCommitteeTimeoutUpdated(newCommitteeTimeout);

        // Act
        vm.prank(owner);
        registry.setPendingCommitteeTimeout(newCommitteeTimeout);
    }

    function test_setCommitteeMinWatchtowers_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 newMinWatchtowers = registry.committeeMemberCount() - registry.minCommitteeOperators(); // to be sure committeeMemberCount >= newMin + minCommitteeOperators
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinWatchtowersUpdated(newMinWatchtowers);

        // Act
        vm.prank(owner);
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);
    }

    function test_setCommitteeMinOperators_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 newMinOperators = registry.committeeMemberCount() - registry.minCommitteeWatchtowers(); // to be sure committeeMemberCount >= minCommitteeWatchtowers + newMin
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinOperatorsUpdated(newMinOperators);

        // Act
        vm.prank(owner);
        registry.setCommitteeMinOperators(newMinOperators);
    }

    function test_setCommitteeMemberCount_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 memberCount = registry.minCommitteeWatchtowers() + registry.minCommitteeOperators(); // to be sure memberCount >= minCommitteeWatchtowers + minCommitteeOperators
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMemberCountUpdated(memberCount);

        // Act
        vm.prank(owner);
        registry.setCommitteeMemberCount(memberCount);
    }

    function test_releaseCommittee_Success_PausedContract() external {
        // Arrange
        // create committee to be released
        setup_pendingCommittee();
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        bytes memory committeePubKey = COMMITTEE_PUB_KEY();

        uint64 streamId = uint64(SETUP_PENDING_COMMITTEE_DENOMINATION);
        uint64 packetNumber = 0;
        bytes32[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);
        vm.prank(address(registry));
        streamManager.createNewPacket(streamId, committeeId, committeePubKey, disputeKeys);

        pauseContracts();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMembersReleased(streamId, packetNumber);

        // Act
        vm.prank(address(pegoutManager));
        registry.releaseCommittee(streamId, packetNumber);
    }

    function test_shouldCreateCommittee_AfterInit() external view {
        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
            assertTrue(
                registry.shouldCreateCommitteeHarness(i), "shouldCreateCommittee should be true after initialization"
            );
        }
    }

    function test_setCommitteeMinWatchtowers_Success() external {
        // Arrange
        uint256 newMinWatchtowers = registry.minCommitteeWatchtowers() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinWatchtowersUpdated(newMinWatchtowers);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);

        // Assert
        assertEq(registry.minCommitteeWatchtowers(), newMinWatchtowers, "Committee min watchtowers should be updated");
    }

    function test_setCommitteeMinWatchtowers_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinWatchtowers = registry.minCommitteeWatchtowers() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);
    }

    function test_setCommitteeMinWatchtowers_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinWatchtowers(0);
    }

    function test_setCommitteeMinWatchtowers_Revert_InvalidMinWatchtowers() external {
        address owner = registry.owner();
        uint256 minMembers = registry.committeeMemberCount();
        uint256 minOperators = registry.minCommitteeOperators();
        uint256 invalidMinWatchtowers = minMembers - minOperators + 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinWatchtowers.selector, minMembers, invalidMinWatchtowers, minOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinWatchtowers(invalidMinWatchtowers);
    }

    function test_setCommitteeMinOperators_Success() external {
        // Arrange
        uint256 newMinOperators = registry.minCommitteeOperators() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinOperatorsUpdated(newMinOperators);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMinOperators(newMinOperators);

        // Assert
        assertEq(registry.minCommitteeOperators(), newMinOperators, "Committee min operators should be updated");
    }

    function test_setCommitteeMinOperators_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinOperators = registry.minCommitteeOperators() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMinOperators(newMinOperators);
    }

    function test_setCommitteeMinOperators_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinOperators(0);
    }

    function test_setCommitteeMinOperators_Revert_InvalidMinOperators() external {
        address owner = registry.owner();
        uint256 minMembers = registry.committeeMemberCount();
        uint256 minWatchtowers = registry.minCommitteeWatchtowers();
        uint256 invalidMinOperators = minMembers - minWatchtowers + 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinOperators.selector, minMembers, minWatchtowers, invalidMinOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinOperators(invalidMinOperators);
    }

    function test_setCommitteeMemberCount_Success() external {
        // Arrange
        uint256 newMinMembers = registry.committeeMemberCount() + 1;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMemberCountUpdated(newMinMembers);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMemberCount(newMinMembers);

        // Assert
        assertEq(registry.committeeMemberCount(), newMinMembers, "Committee min members should be updated");
    }

    function test_setCommitteeMemberCount_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinMembers = registry.committeeMemberCount() + 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMemberCount(newMinMembers);
    }

    function test_setCommitteeMemberCount_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMemberCount(0);
    }

    function test_setCommitteeMemberCount_Revert_InvalidMinMembers() external {
        address owner = registry.owner();
        uint256 minWatchtowers = registry.minCommitteeWatchtowers();
        uint256 minOperators = registry.minCommitteeOperators();
        uint256 invalidMinMembers = minWatchtowers + minOperators - 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinMembers.selector, invalidMinMembers, minWatchtowers, minOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMemberCount(invalidMinMembers);
    }

    function test_setCommitteeMemberCount_Success_AtMaximum() external {
        // Arrange
        address owner = registry.owner();
        uint256 maxCommitteeMemberCount = Constants.MAX_COMMITTEE_MEMBER_COUNT;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMemberCountUpdated(maxCommitteeMemberCount);

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMemberCount(maxCommitteeMemberCount);

        // Assert
        assertEq(
            registry.committeeMemberCount(),
            maxCommitteeMemberCount,
            "Committee member count should be set to maximum allowed value"
        );
    }

    function test_setCommitteeMemberCount_Revert_InvalidMaxMembers() external {
        // Arrange
        address owner = registry.owner();
        uint256 maxCommitteeMemberCount = Constants.MAX_COMMITTEE_MEMBER_COUNT;
        uint256 exceedingCount = maxCommitteeMemberCount + 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMaxMembers.selector, maxCommitteeMemberCount, exceedingCount
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMemberCount(exceedingCount);
    }

    function assertAddressesAreWhitelisted(address[] memory _addresses) private view {
        for (uint256 i = 0; i < _addresses.length; i++) {
            assertAddressIsWhitelisted(_addresses[i]);
        }
    }

    function assertAddressIsWhitelisted(address _address) private view {
        assertTrue(registry.isWhitelisted(_address));
    }

    function assertAddressesAreUnwhitelisted(address[] memory _addresses) private view {
        for (uint256 i = 0; i < _addresses.length; i++) {
            assertAddressIsUnwhitelisted(_addresses[i]);
        }
    }

    function assertAddressIsUnwhitelisted(address _address) private view {
        assertFalse(registry.isWhitelisted(_address));
    }

    function assertMemberIsNotStreamCandidateForRole(StreamDenomination _denomination, Role _role, address _address)
        private
        view
    {
        address[] memory streamCandidates = memberRegistry.getCommitteeCandidates(_denomination, _role);
        bool isCandidate;
        for (uint256 i = 0; i < streamCandidates.length; i++) {
            if (streamCandidates[i] == _address) {
                isCandidate = true;
            }
        }
        assertFalse(isCandidate);
    }

    function assertMembersReApplyDisabledForStream(StreamDenomination _denomination, address[] memory _addresses)
        private
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            assertMemberReApplyDisabledForStream(_denomination, _addresses[i]);
        }
    }

    function assertMemberReApplyDisabledForStream(StreamDenomination _denomination, address _address) private {
        vm.prank(_address);
        assertFalse(memberRegistry.getReApplyForStream(_denomination));
    }

    function test_whitelistAddress_Success() external {
        // Arrange
        address addressToWhitelist = address(0x123);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressWhitelisted(addressToWhitelist);

        // Act
        vm.prank(registry.whitelister());
        registry.whitelistAddress(addressToWhitelist);

        // Assert
        assertAddressIsWhitelisted(addressToWhitelist);
    }

    function test_whitelistAddress_Revert_UnauthorizedAccount() external {
        // Arrange
        address addressToWhitelist = address(0x123);
        address unauthorizedCaller = address(0x12345);

        // Assert
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedWhitelister.selector, unauthorizedCaller));

        // Act
        registry.whitelistAddress(addressToWhitelist);
    }

    function test_whitelistAddresses_Success() external {
        // Arrange
        address addressToWhitelist1 = address(0x123);
        address addressToWhitelist2 = address(0x456);
        address[] memory addressesToWhitelist = new address[](2);
        addressesToWhitelist[0] = addressToWhitelist1;
        addressesToWhitelist[1] = addressToWhitelist2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressWhitelisted(addressToWhitelist1);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressWhitelisted(addressToWhitelist2);

        // Act
        vm.prank(registry.whitelister());
        registry.whitelistAddresses(addressesToWhitelist);

        // Assert
        assertAddressesAreWhitelisted(addressesToWhitelist);
    }

    function test_whitelistAddresses_Revert_UnauthorizedAccount() external {
        // Arrange
        address addressToWhitelist1 = address(0x123);
        address addressToWhitelist2 = address(0x456);
        address[] memory addressesToWhitelist = new address[](2);
        addressesToWhitelist[0] = addressToWhitelist1;
        addressesToWhitelist[1] = addressToWhitelist2;

        address unauthorizedCaller = address(0x12345);

        // Assert
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedWhitelister.selector, unauthorizedCaller));

        // Act
        registry.whitelistAddresses(addressesToWhitelist);
    }

    function test_unwhitelistAddress_Success() external {
        // Arrange
        address addressToUnwhitelist = address(0x123);
        vm.prank(registry.whitelister());
        registry.whitelistAddress(addressToUnwhitelist);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddress(addressToUnwhitelist);

        // Assert
        assertAddressIsUnwhitelisted(addressToUnwhitelist);
    }

    function test_unwhitelistAddress_Success_whenIsInActiveCommittee() external {
        // Arrange
        setup_completeCommittee();
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address addressToUnwhitelist = committeeMembers[0].memberAddress;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberReApplyUpdated(addressToUnwhitelist, DEFAULT_STREAM, false);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddress(addressToUnwhitelist);

        // Assert
        assertAddressIsUnwhitelisted(addressToUnwhitelist);
        assertMemberReApplyDisabledForStream(DEFAULT_STREAM, addressToUnwhitelist);
    }

    function test_unwhitelistAddress_Success_whenIsInPendingCommittee() external {
        // Arrange
        setup_pendingCommittee();
        CommitteeMember[] memory allMembers = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address addressToUnwhitelist = allMembers[0].memberAddress;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(addressToUnwhitelist, uint256(25000000 gwei), uint256(25000000 gwei));
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressToUnwhitelist, DEFAULT_STREAM);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddress(addressToUnwhitelist);

        // Assert
        assertAddressIsUnwhitelisted(addressToUnwhitelist);
        assertMemberIsNotStreamCandidateForRole(DEFAULT_STREAM, DEFAULT_ROLE, addressToUnwhitelist);

        // after removing the address, we dont have enough members to create a new pending committee
        uint128 expectedCommitteeId = 0;
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, expectedCommitteeId));
        registry.getPendingCommittee(uint64(DEFAULT_STREAM));
    }

    function test_unwhitelistAddress_Success_whenIsJustSubscribedToStream() external {
        // Arrange
        address addressToUnwhitelist = address(0x123);
        MemberRegistrationKeys memory memberRegistrationKeys =
            generateRegistrationPublicKeys(uint256(uint160(addressToUnwhitelist)));
        setup_applyToStream(DEFAULT_STREAM, addressToUnwhitelist, memberRegistrationKeys, DEFAULT_ROLE);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(addressToUnwhitelist, uint256(25000000 gwei), uint256(25000000 gwei));
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressToUnwhitelist, DEFAULT_STREAM);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddress(addressToUnwhitelist);

        // Assert
        assertAddressIsUnwhitelisted(addressToUnwhitelist);
        assertMemberIsNotStreamCandidateForRole(DEFAULT_STREAM, DEFAULT_ROLE, addressToUnwhitelist);
    }

    function test_unwhitelistAddress_Revert_UnauthorizedAccount() external {
        // Arrange
        address addressToUnwhitelist = address(0x123);
        address unauthorizedCaller = address(0x12345);

        // Assert
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedWhitelister.selector, unauthorizedCaller));

        // Act
        registry.unwhitelistAddress(addressToUnwhitelist);
    }

    function test_unwhitelistAddresses_Success() external {
        // Arrange
        address[] memory addressesToUnwhitelist = new address[](2);
        address addressToUnwhitelist1 = address(0x123);
        address addressToUnwhitelist2 = address(0x456);
        addressesToUnwhitelist[0] = addressToUnwhitelist1;
        addressesToUnwhitelist[1] = addressToUnwhitelist2;

        // whitelist the addresses
        vm.prank(registry.whitelister());
        registry.whitelistAddresses(addressesToUnwhitelist);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist1);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressToUnwhitelist2);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddresses(addressesToUnwhitelist);

        // Assert
        assertAddressesAreUnwhitelisted(addressesToUnwhitelist);
    }

    function test_unwhitelistAddresses_Success_whenAreInSameActiveCommittee() external {
        // Arrange
        setup_completeCommittee();
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address[] memory addressesToUnwhitelist = new address[](2);
        addressesToUnwhitelist[0] = members[0].memberAddress;
        addressesToUnwhitelist[1] = members[1].memberAddress;

        // Assert
        // logs when unwhitelisting first address
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[0]);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberReApplyUpdated(addressesToUnwhitelist[0], DEFAULT_STREAM, false);

        // logs when unwhitelisting second address
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[1]);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberReApplyUpdated(addressesToUnwhitelist[1], DEFAULT_STREAM, false);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddresses(addressesToUnwhitelist);

        // Assert
        assertAddressesAreUnwhitelisted(addressesToUnwhitelist);
        assertMembersReApplyDisabledForStream(DEFAULT_STREAM, addressesToUnwhitelist);
    }

    function test_unwhitelistAddresses_Success_whenAreInSamePendingCommittee() external {
        // Arrange
        // register more candidates than minimum required
        // so new pending committee is created after restart
        uint256 numOperators = registry.committeeMemberCount();
        uint256 numWatchtowers = registry.committeeMemberCount();
        setup_registerNewMembers(numWatchtowers, numOperators, SETUP_PENDING_COMMITTEE_DENOMINATION);

        uint128 committeeId = registry.getPendingCommitteeId(SETUP_PENDING_COMMITTEE_STREAM_ID);
        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        address[] memory addressesToUnwhitelist = new address[](2);
        addressesToUnwhitelist[0] = members[0].memberAddress;
        addressesToUnwhitelist[1] = members[1].memberAddress;

        // Assert
        // logs when unwhitelisting first address
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[0]);

        // values of new pending committee log cannot be checked since it does not exist yet
        Committee memory dummyNewPendingCommittee;
        uint128 dummyNewPendingCommitteeId;
        vm.expectEmit(false, false, false, false, address(registry));

        emit ICommitteeRegistry.NewPendingCommittee(dummyNewPendingCommitteeId, dummyNewPendingCommittee);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(
            addressesToUnwhitelist[0], uint256(25000000 gwei), uint256(25000000 gwei)
        );
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[0], DEFAULT_STREAM);

        // logs when unwhitelisting second address
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[1]);
        // new pending committee will not be reset again,
        // so no NewPendingCommittee log should be emitted again
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(
            addressesToUnwhitelist[1], uint256(25000000 gwei), uint256(25000000 gwei)
        );
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[1], DEFAULT_STREAM);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddresses(addressesToUnwhitelist);

        // Assert
        assertAddressesAreUnwhitelisted(addressesToUnwhitelist);
        for (uint256 i = 0; i < addressesToUnwhitelist.length; i++) {
            assertMemberIsNotStreamCandidateForRole(DEFAULT_STREAM, members[i].role, addressesToUnwhitelist[i]);
        }
    }

    function test_unwhitelistAddresses_Success_whenAreInDifferentPendingCommittees() external {
        // Arrange
        // register more candidates than minimum required
        // so new pending committees are created after restart
        uint256 numOperators = registry.committeeMemberCount();
        uint256 numWatchtowers = registry.committeeMemberCount();
        // register members for two different streams
        setup_registerNewMembers(numWatchtowers, numOperators, SETUP_PENDING_COMMITTEE_DENOMINATION);
        StreamDenomination anotherDenomination = StreamDenomination._0_1BTC;
        setup_registerNewMembers(numWatchtowers, numOperators, anotherDenomination);

        uint128 firstCommitteeId = registry.getPendingCommitteeId(SETUP_PENDING_COMMITTEE_STREAM_ID);
        CommitteeMember[] memory firstCommitteeMembers = registry.getCommitteeMembers(firstCommitteeId);
        CommitteeMember memory memberOfFirstCommittee = firstCommitteeMembers[0];

        uint128 secondCommitteeId = registry.getPendingCommitteeId(uint64(anotherDenomination));
        CommitteeMember[] memory secondCommitteeMembers = registry.getCommitteeMembers(secondCommitteeId);
        CommitteeMember memory memberOfSecondCommittee = secondCommitteeMembers[0];

        address[] memory addressesToUnwhitelist = new address[](2);
        addressesToUnwhitelist[0] = memberOfFirstCommittee.memberAddress;
        addressesToUnwhitelist[1] = memberOfSecondCommittee.memberAddress;

        // Assert
        // logs when unwhitelisting address that belong to first stream
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[0]);
        // values of new pending committee log cannot be checked since it does not exist yet
        Committee memory dummyNewPendingCommittee;
        uint128 dummyNewPendingCommitteeId;
        vm.expectEmit(false, false, false, false, address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(dummyNewPendingCommitteeId, dummyNewPendingCommittee);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(
            addressesToUnwhitelist[0], uint256(25000000 gwei), uint256(25000000 gwei)
        );
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[0], DEFAULT_STREAM);

        // logs when unwhitelisting address that belong to second stream
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[1]);
        // values of new pending committee log cannot be checked since it does not exist yet
        vm.expectEmit(false, false, false, false, address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(dummyNewPendingCommitteeId, dummyNewPendingCommittee);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.NewAvailableBalance(
            addressesToUnwhitelist[1], uint256(25000000 gwei), uint256(25000000 gwei)
        );
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[1], anotherDenomination);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddresses(addressesToUnwhitelist);

        // Assert
        assertAddressesAreUnwhitelisted(addressesToUnwhitelist);
        assertMemberIsNotStreamCandidateForRole(DEFAULT_STREAM, memberOfFirstCommittee.role, addressesToUnwhitelist[0]);
        assertMemberIsNotStreamCandidateForRole(
            anotherDenomination, memberOfSecondCommittee.role, addressesToUnwhitelist[1]
        );
    }

    function test_unwhitelistAddresses_Success_whenAreJustSubscribedToStream() external {
        address address1 = address(0x123);
        MemberRegistrationKeys memory registrationKeys1 = generateRegistrationPublicKeys(uint256(uint160(address1)));
        setup_applyToStream(DEFAULT_STREAM, address1, registrationKeys1, DEFAULT_ROLE);
        address address2 = address(0x456);
        MemberRegistrationKeys memory registrationKeys2 = generateRegistrationPublicKeys(uint256(uint160(address2)));
        setup_applyToStream(DEFAULT_STREAM, address2, registrationKeys2, DEFAULT_ROLE);

        address[] memory addressesToUnwhitelist = new address[](2);
        addressesToUnwhitelist[0] = address1;
        addressesToUnwhitelist[1] = address2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[0]);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[0], DEFAULT_STREAM);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AddressUnwhitelisted(addressesToUnwhitelist[1]);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(addressesToUnwhitelist[1], DEFAULT_STREAM);

        // Act
        vm.prank(registry.whitelister());
        registry.unwhitelistAddresses(addressesToUnwhitelist);

        // Assert
        assertAddressesAreUnwhitelisted(addressesToUnwhitelist);
        for (uint256 i = 0; i < addressesToUnwhitelist.length; i++) {
            assertMemberIsNotStreamCandidateForRole(DEFAULT_STREAM, DEFAULT_ROLE, addressesToUnwhitelist[i]);
        }
    }

    function test_unwhitelistAddresses_Revert_UnauthorizedAccount() external {
        // Arrange
        address[] memory addressesToUnwhitelist = new address[](2);
        address addressToUnwhitelist1 = address(0x123);
        address addressToUnwhitelist2 = address(0x456);

        // whitelist the addresses
        vm.prank(registry.whitelister());
        registry.whitelistAddress(addressToUnwhitelist1);
        vm.prank(registry.whitelister());
        registry.whitelistAddress(addressToUnwhitelist2);

        addressesToUnwhitelist[0] = addressToUnwhitelist1;
        addressesToUnwhitelist[1] = addressToUnwhitelist2;
        address unauthorizedCaller = address(0x12345);

        // Assert
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedWhitelister.selector, unauthorizedCaller));

        // Act
        registry.unwhitelistAddresses(addressesToUnwhitelist);
    }

    function test_applyToStream_Revert_NonWhitelistedAddress() external {
        // Arrange
        uint256 privKey = uint256(1);
        address userAddress = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(userAddress, 1 ether);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonWhitelistedAddress.selector, userAddress));

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Success_WhitelistedAddress() external {
        // Arrange
        uint256 privKey = uint256(1);
        address userAddress = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(userAddress, 1 ether);

        vm.prank(registry.whitelister());
        registry.whitelistAddress(userAddress);

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_getCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        // Act
        Committee memory committee = registry.getCommittee(committeeId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committees are not equal");
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "shouldCreateCommittee should be false after setup completeCommittee call"
        );

        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
            if (i != expectedCommittee.streamId) {
                assertTrue(
                    registry.shouldCreateCommitteeHarness(i),
                    "shouldCreateCommittee should be true after initialization"
                );
            }
        }
    }

    function test_getCommitteeMembers_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_completeCommittee();

        // Act
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        // Assert
        assertEqCommitteeMembersSelection(expectedCommittee.members, members, "Member list are not equal");
    }

    function test_selectCommittee_Success_MinOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators;

        // Act
        // selectCommittee should be called internally when enough members have applied for the stream
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);
        Committee memory pendingCommittee = registry.getPendingCommittee(streamId);
        CommitteeMember[] memory selectedMembers = pendingCommittee.members;

        // Assert - Verify committee has correct size
        assertEq(selectedMembers.length, registry.committeeMemberCount(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.WATCHTOWER) watchtowerCount++;
            else if (selectedMembers[i].role == Role.OPERATOR) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, numWatchtowers, "Wrong amount of watchtowers");
        assertEq(operatorCount, numOperators, "Wrong amount of operators");

        assertUniqueMembers(selectedMembers);
    }

    function assertUniqueMembers(CommitteeMember[] memory selectedMembers) internal pure {
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            for (uint256 j = i + 1; j < selectedMembers.length; j++) {
                assertNotEq(
                    selectedMembers[i].memberAddress,
                    selectedMembers[j].memberAddress,
                    "There is a repeated member in selected members"
                );
            }
        }
    }

    function test_selectCommittee_Success_MinWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.committeeMemberCount() - numWatchtowers;

        // Act
        // selectCommittee should be called internally when enough members have applied for the stream
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);
        Committee memory pendingCommittee = registry.getPendingCommittee(streamId);
        CommitteeMember[] memory selectedMembers = pendingCommittee.members;

        // Assert - Verify committee has correct size
        assertEq(selectedMembers.length, registry.committeeMemberCount(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.WATCHTOWER) watchtowerCount++;
            else if (selectedMembers[i].role == Role.OPERATOR) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, numWatchtowers, "Wrong amount of watchtowers");
        assertEq(operatorCount, numOperators, "Wrong amount of operators");

        assertUniqueMembers(selectedMembers);
    }

    function test_selectCommittee_TwiceWithSameMembers_ReturnsDifferentOrderOfMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        // to choose same members twice we should need all the available candidates,
        // so we can't register more than the minimum required
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.committeeMemberCount() - numWatchtowers;

        // Set different BTC block headers for different RSK block numbers to ensure different entropy
        // BTC block header for RSK block 1001
        bridgeMock.setHeader(
            1001,
            hex"0000003c9d087b22bc8c482ad398dcfed27a115490cfbc144b3801000000000000000000a923a1461ac1dd2b222f3525f071bec2026acee9038ee440d6915488894a1452e7d66b6816680217f35754aa"
        );
        // Different BTC block header for RSK block 2000
        bridgeMock.setHeader(
            2000,
            hex"00000020f3b5e8e3a8d4c2b1a0908f7e6d5c4b3a291817060504030201000000000000009f8e7d6c5b4a39281716050403020100ffeeddccbbaa99887766554433221100aaaabbbb1d00ffff00000000"
        );

        // First selection with block 1001
        vm.roll(1001);
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        Committee memory pendingCommittee1 = registry.getPendingCommittee(streamId);
        CommitteeMember[] memory selectedMembers1 = pendingCommittee1.members;
        assertUniqueMembers(selectedMembers1);
        assertEq(selectedMembers1.length, registry.committeeMemberCount(), "First committee should have 10 members");

        // we need members not to reapply to stream when resetting the committee
        // to be able to register them again in the same order
        for (uint256 i = 0; i < selectedMembers1.length; i++) {
            address memberAddress = selectedMembers1[i].memberAddress;
            vm.prank(memberAddress);
            memberRegistry.setReApplyForStream(denomination, false);
        }

        uint256 expiresAt = pendingCommittee1.createdAt + registry.pendingCommitteeTimeout();
        vm.warp(expiresAt);
        vm.roll(expiresAt);
        registry.restartPendingCommittee(streamId);

        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        Committee memory pendingCommittee2 = registry.getPendingCommittee(streamId);
        CommitteeMember[] memory selectedMembers2 = pendingCommittee2.members;
        assertUniqueMembers(selectedMembers2);
        assertEq(selectedMembers2.length, registry.committeeMemberCount(), "Second committee should have 10 members");

        assertEqCommitteeStructure(pendingCommittee1, pendingCommittee2);
        assertDifferentMembersSelection(selectedMembers1, selectedMembers2);
    }

    function test_selectCommittee_Emit_MissingWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 minWatchtowers = registry.minCommitteeWatchtowers() - 1;
        uint256 numOperators = registry.committeeMemberCount() - minWatchtowers + 1;
        setup_registerNewMembers(minWatchtowers, numOperators, denomination);

        // Assert that selectCommittee emits MissingWatchtowers event
        vm.expectEmit(address(memberRegistry));

        emit IMemberRegistry.MissingWatchtowers(denomination, registry.minCommitteeWatchtowers(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_WATCHTOWERS,
            "Committee selection should fail due to not enough watchtowers"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Emit_MissingOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators() - 1;
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators + 1;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert that selectCommittee emits MissingOperators event
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MissingOperators(denomination, registry.minCommitteeOperators(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_OPERATORS,
            "Committee selection should fail due to not enough operators"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Emit_MissingMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MissingMembers(
            denomination,
            registry.committeeMemberCount(),
            registry.committeeMemberCount() - registry.minCommitteeOperators() - registry.minCommitteeWatchtowers()
        );

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_MEMBERS,
            "Committee selection should fail due to not enough members"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(0);
    }

    function test_createCommittee_Success_WithNewMembers() external {
        // This test should register all the members for a committee. This will trigger the creation of a pending committee.
        // We should complete that committee and then, with all the new members registered, we should be able to create a committee.
        // Arrange
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = new bytes(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(committeeId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(peginManager));
        registry.createCommittee(expectedCommittee.streamId);

        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committee should be equeals");
        assertNotEq(committee.createdAt, 0, "Created at should not be 0");
        assertEq(
            committee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to committeeMemberCount"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_createCommittee_Success_SameMembersAfterReApply() external {
        // After first committee is ready all the members apply again to the stream and create a new committee.
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);

        assertEq(0, memberRegistry.getCommitteeCandidates(denomination, Role.OPERATOR).length);
        assertEq(0, memberRegistry.getCommitteeCandidates(denomination, Role.WATCHTOWER).length);

        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        vm.warp(BLOCK_COMMITTEE_3);
        vm.roll(BLOCK_COMMITTEE_3);
        setup_applyToStream_MultipleMembers(denomination, numWatchtowers, numOperators, 0);

        Committee memory expectedCommittee = setup_getExpectedCommitteeAfterExpire();
        expectedCommittee.aggregatedKey = new bytes(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(committee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(peginManager));
        registry.createCommittee(committee.streamId);

        Committee memory pendingCommittee = registry.getPendingCommittee(committee.streamId);
        // Assert
        assertEqCommittee(expectedCommittee, pendingCommittee, "Committee should be equeals");
        assertNotEq(committee.createdAt, 0, "Created at should not be 0");
        assertEq(
            pendingCommittee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to committeeMemberCount"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(committee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_createCommittee_Success_AlreadyPendingButNotExpired() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        Committee memory pendingCommittee = registry.getPendingCommittee(expectedCommittee.streamId);
        vm.recordLogs();

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );

        // createCommittee called by pegManager should do nothing if pending committee is not expired
        // Act
        vm.prank(address(peginManager));
        registry.createCommittee(expectedCommittee.streamId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);

        assertEq(pendingCommittee.createdAt, pendingCommitteeAfterCall.createdAt, "Pending committee should not change");
        assertEq(
            pendingCommittee.missingData, pendingCommitteeAfterCall.missingData, "Pending committee should not change"
        );
        assertEq(
            pendingCommittee.aggregatedKey,
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembersSelection(
            pendingCommittee.members, pendingCommitteeAfterCall.members, "Create committee should not change members"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false after createCommittee call success"
        );
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();

        // Act
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);

        // Assert
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount());
    }

    function test_depositAggregatedKey_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberInfoDeposited(committeeId, vm.addr(1), COMMITTEE_PUB_KEY());

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount() - 1);
    }

    function test_depositAggregatedKey_Revert_MemberInfoAlreadyDeposited() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        address memberAddress = vm.addr(1);
        // Deposit data for the first time
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberInfoAlreadyDeposited.selector, committeeId, memberAddress)
        );

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_Revert_MemberNotInCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        address notCommitteeMember = vm.addr(registry.committeeMemberCount() + 1);
        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(notCommitteeMember)));
        setup_applyToStream(
            StreamDenomination(expectedCommittee.streamId), notCommitteeMember, publicKeysRegistration, Role.OPERATOR
        );

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, notCommitteeMember)
        );

        // Act
        vm.prank(notCommitteeMember);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_Revert_InvalidAggregatedKeyLength() external {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAggregatedKeyLength.selector, 0, 33));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, new bytes(0));
    }

    function test_depositAggregatedKey_Revert_InvalidAggregatedKeyZero() external {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();
        bytes memory zeroKey = new bytes(33); // All zeros, 33 bytes

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAggregatedKeyZero.selector));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, zeroKey);
    }

    function test_depositAggregatedKey_Revert_CommitteeIsNotPending() external {
        // Arrange
        uint128 committeeId = 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, committeeId));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_WrongCommitteeKey_TriggersNewPendingCommitteeCreation() external {
        // Arrange
        (, uint128 firstCommitteeId) = setup_pendingCommittee();
        Committee memory firstPendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);

        // Deposit correct aggregated key for the first member
        setup_depositAggregatedKey(firstCommitteeId, vm.addr(1));

        // advance blockchain so timestamp is different and new committee can be created
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Act
        // Another member deposits wrong aggregated key for the first committee,
        // so it will be discarded and a new one will be created
        vm.prank(vm.addr(2));
        bytes memory wrongPubKey =
            abi.encodePacked(bytes1(0x03), bytes32(0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec));
        registry.depositAggregatedKey(firstCommitteeId, wrongPubKey);

        // Assert
        // the current pending committee should be the one created after depositing the wrong key
        Committee memory pendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);
        assertEq(pendingCommittee.missingData, registry.committeeMemberCount());
        assertEqCommitteeStructure(pendingCommittee, firstPendingCommittee);
    }

    function test_depositAggregatedKey_Success_CompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.missingData = 0;
        expectedCommittee.isPending = false;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount() - 1;
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.committeeMemberCount()));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.WATCHTOWER)
                .length,
            0,
            "Should not have candidates after committee created"
        );
        // Verify there is 1 active committee by checking active packets length
        Stream memory stream = streamManager.getStreamById(expectedCommittee.streamId);
        uint64 packetsLength = streamManager.getPacketsLength(expectedCommittee.streamId);
        assertEq(packetsLength, 1, "Should have 1 active committee after completion");
        uint128 activeCommitteeId = streamManager.getCommitteeId(expectedCommittee.streamId, 0);
        assertEq(activeCommitteeId, committeeId, "Active committee should match the completed one");
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount();
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(expectedCommittee.streamId);
    }

    function test_isPendingCommitteeExpired_False_BeforeCreateCommittee() external view {
        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(0);
        // Assert
        // There is no pending committee so it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterCreateCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        setup_depositAggregatedKey(committeeId, vm.addr(1));

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterSomeSeconds() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        setup_depositAggregatedKey(committeeId, vm.addr(1));
        vm.warp(block.timestamp + 60 seconds); // warp time but amount of time is not enough to expire the committee

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_True_ChangingTimeout() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        vm.warp(block.timestamp + 60 seconds); // warp time to make committee expired

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(30 seconds);

        // Assert
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_isPendingCommitteeExpired_True_AfterTimeout() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's expired
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_createCommittee_Success_AfterExpiredCommittee() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        // Act
        vm.prank(address(peginManager));
        registry.createCommittee(expectedCommittee.streamId);

        // Assert
        Committee memory actualPendingCommittee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommitteeStructure(actualPendingCommittee, expectedCommittee);
        assertEq(actualPendingCommittee.createdAt, BLOCK_COMMITTEE_3);
        assertEq(actualPendingCommittee.missingData, registry.committeeMemberCount());
    }

    function test_depositAggregatedKey_Success_CompleteCommitteeOnExpiredCommittee() external {
        // Having an expired committee does not prevent members to still deposit their data
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.missingData = 0;
        expectedCommittee.isPending = false;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount() - 1;
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.committeeMemberCount()));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(expectedCommittee.streamId);

        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.WATCHTOWER)
                .length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_setPendingCommitteeTimeout_Success() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PendingCommitteeTimeoutUpdated(newTimeout);

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(newTimeout);

        // Assert
        assertEq(registry.pendingCommitteeTimeout(), newTimeout, "Pending committee timeout should be updated");
    }

    function test_setPendingCommitteeTimeout_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setPendingCommitteeTimeout(newTimeout);
    }

    function test_setPendingCommitteeTimeout_Revert_InvalidZeroTimeout() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setPendingCommitteeTimeout(0);
    }

    function test_createCommittee_UnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(this)));

        // Act
        registry.createCommittee(0);
    }

    function test_restartPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));

        // Act
        registry.restartPendingCommittee(0);
    }

    function test_restartPendingCommittee_Revert_PendingCommitteeNotExpired() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        setup_depositAggregatedKey(committeeId, vm.addr(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PendingCommitteeNotExpired.selector,
                expectedCommittee.streamId,
                BLOCK_COMMITTEE_1,
                86410
            )
        );

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);
    }

    function test_restartPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedPendingCommittee,) = setup_pendingCommitteeAndExpire();
        uint64 streamId = expectedPendingCommittee.streamId;

        // Act
        registry.restartPendingCommittee(streamId);

        // Assert
        Committee memory pendingCommittee = registry.getPendingCommittee(streamId);
        assertEqCommitteeStructure(pendingCommittee, expectedPendingCommittee);
        assertEq(pendingCommittee.createdAt, BLOCK_COMMITTEE_3);
        assertEq(
            pendingCommittee.missingData,
            registry.committeeMemberCount(),
            "missing data should be equal to min committee members"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NotExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        StreamDenomination denomination = StreamDenomination(expectedCommittee.streamId);
        Committee memory pendingCommitteeBeforeCall = registry.getPendingCommittee(expectedCommittee.streamId);
        vm.recordLogs();

        // createCommitteeAfterApplyToStream called should do nothing if pending committee is not expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEq(
            pendingCommitteeAfterCall.createdAt,
            pendingCommitteeBeforeCall.createdAt,
            "Pending committee should not change"
        );
        assertEq(
            pendingCommitteeAfterCall.missingData,
            pendingCommitteeBeforeCall.missingData,
            "Pending committee should not change"
        );
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembersSelection(
            pendingCommitteeAfterCall.members, expectedCommittee.members, "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_ExpiredPendingCommittee() external {
        // Arrange
        setup_pendingCommittee();
        Committee memory firstPendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);
        // advance blockchain to expire pending committee
        vm.warp(BLOCK_COMMITTEE_3);
        vm.roll(BLOCK_COMMITTEE_3);

        // Act
        // should create a new pending committee if the previous one is expired
        StreamDenomination denomination = StreamDenomination(SETUP_PENDING_COMMITTEE_STREAM_ID);
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Committee memory actualPendingCommittee = registry.getPendingCommittee(SETUP_PENDING_COMMITTEE_STREAM_ID);
        assertEqCommitteeStructure(actualPendingCommittee, firstPendingCommittee);
        assertNotEq(actualPendingCommittee.createdAt, firstPendingCommittee.createdAt);
        assertEq(
            actualPendingCommittee.missingData,
            actualPendingCommittee.members.length,
            "Pending committee should not change"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NoCommitteeForCurrentPacket() external {
        // In this case we want to test the case where we run out of slots from current packet without being ables to create a new pending committee.
        // This is a edge case where we had the minimum of members to create first packet but one of the members decided to unsubscribe from the stream for next packet
        // So pending committee wont be created in each of the last pegins of current packet. Resulting in no pending committee for next packet.
        // applyToStream call internally to `createCommitteeAfterApplyToStream`

        // ===== Arrange start =====
        // Create a complete committee for initial packet
        setup_completeCommitteeAndNewMembers();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;
        StreamDenomination denomination = StreamDenomination(streamId);
        // Need to use last member in the committee to unsubscribe and subscribe to keep same random committee member order
        uint256 userIndex = registry.committeeMemberCount() * 2 - 1;
        Role userRole = Role.OPERATOR;
        address userAddress = vm.addr(userIndex + 1);
        MemberRegistrationKeys memory memberRegistrationKeys =
            generateRegistrationPublicKeys(uint256(uint160(userAddress)));

        // Unsubscribe one of the members
        vm.prank(userAddress);
        registry.unsubscribeFromStream(denomination);

        // Use all the slots in the packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET);

        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 1, "Stream pegin packet pointer should be 1 after filling all slots");

        // Check that current packet does not have a committee
        uint256 currentPacketCommitteeId = streamManager.getAvailablePeginCommitteeId(streamId);
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");

        // Check there is no pending committee
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        registry.getPendingCommittee(streamId);

        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, userRole);
        vm.deal(userAddress, minimumDeposit);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();
        vm.warp(BLOCK_COMMITTEE_2);
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be true because there is no pending committee and need one to new packet"
        );
        // ===== Arrange end =====

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_2, expectedCommittee);

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(
            denomination, userRole, memberRegistrationKeys, generateDefaultUTXO()
        );

        // Assert
        Committee memory pendingCommittee = registry.getPendingCommittee(streamId);
        assertEqCommittee(pendingCommittee, expectedCommittee, "get pending committee after apply to stream");
        assertNotEq(pendingCommittee.createdAt, 0, "Created at should not be 0 after apply to stream");
        assertEq(
            pendingCommittee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to min committee members"
        );
        assertFalse(registry.shouldCreateCommitteeHarness(streamId), "Flag should be false before createCommittee call");
    }

    function test_applyToStream_Revert_TooManyCandidatesForStream_Operator() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_registerNewMembers(0, Constants.MAX_CANDIDATES_SIZE_PER_ROLE, denomination);

        address extraMemberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE + 1);
        // manually whitelist the extra address
        setup_whitelistAddress(extraMemberAddress);

        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(extraMemberAddress)));
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(extraMemberAddress, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMemberRegistry.TooManyCandidatesForStream.selector, denomination, role));

        // Act
        vm.prank(extraMemberAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, role, publicKeysRegistration, generateDefaultUTXO());
    }

    function test_applyToStream_Revert_TooManyCandidatesForStream_Watchtower() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.WATCHTOWER;
        setup_registerNewMembers(Constants.MAX_CANDIDATES_SIZE_PER_ROLE, 0, denomination);

        address extraMemberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE + 1);
        // manually whitelist the extra address
        setup_whitelistAddress(extraMemberAddress);

        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(extraMemberAddress)));
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(extraMemberAddress, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMemberRegistry.TooManyCandidatesForStream.selector, denomination, role));

        // Act
        vm.prank(extraMemberAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, role, publicKeysRegistration, generateDefaultUTXO());
    }

    function test_unsubscribeFromStream_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the unsubscribeFromStream function
        // based on different values of Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        // unsubscribeFromStream iterate over all the candidates in the stream until it finds the member to unsubscribe.
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 69k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 127k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 129k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 224k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 512: 228k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 1000: 418k gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        setup_registerNewMembers(Constants.MAX_CANDIDATES_SIZE_PER_ROLE, 0, denomination);
        address lastMemberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE);
        uint256 gasStart = gasleft();

        // Act
        vm.prank(lastMemberAddress);
        registry.unsubscribeFromStream(denomination);
        uint256 gasUsed = gasStart - gasleft();

        assertLt(
            gasUsed,
            MAX_GAS_PER_COMMITTEE_CREATION / registry.committeeMemberCount(),
            "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION divided by committeeMemberCount"
        );
    }

    function test_createCommittee_forDifferentCandidatesSize_GasConsumptionCheck() external {
        // This test is to check that the gas used when creating a committee
        // is pretty much the same for 10 and 100 candidates

        // Arrange - create pending committee for stream with 0.01BTC denomination
        StreamDenomination firstDenomination = StreamDenomination._0_01BTC;
        uint64 firstStreamId = uint64(firstDenomination);

        uint256 firstCandidatesSize = 10;
        setup_registerNewMembers(firstCandidatesSize, firstCandidatesSize, firstDenomination);
        Committee memory firstCommittee = registry.getPendingCommittee(firstStreamId);
        CommitteeMember[] memory firstCommitteeMembers = firstCommittee.members;
        uint128 firstCommitteeId = registry.getPendingCommitteeId(firstStreamId);

        for (uint256 i = 0; i < firstCommitteeMembers.length - 1; i++) {
            setup_depositAggregatedKey(firstCommitteeId, firstCommitteeMembers[i].memberAddress);
        }

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(firstStreamId, 0);
        // Act
        uint256 firstGasStart = gasleft();
        vm.prank(firstCommitteeMembers[firstCommitteeMembers.length - 1].memberAddress);
        registry.depositAggregatedKey(firstCommitteeId, COMMITTEE_PUB_KEY());
        uint256 firstCommitteeGasUsed = firstGasStart - gasleft();

        // Arrange - create pending committee for stream with 0.001BTC denomination
        StreamDenomination secondDenomination = StreamDenomination._0_001BTC;
        uint64 secondStreamId = uint64(secondDenomination);

        uint256 secondCandidatesSize = 100;
        setup_registerNewMembers(secondCandidatesSize, secondCandidatesSize, secondDenomination);
        Committee memory secondCommittee = registry.getPendingCommittee(secondStreamId);
        CommitteeMember[] memory secondCommitteeMembers = secondCommittee.members;
        uint128 secondCommitteeId = registry.getPendingCommitteeId(secondStreamId);

        for (uint256 i = 0; i < secondCommitteeMembers.length - 1; i++) {
            setup_depositAggregatedKey(secondCommitteeId, secondCommitteeMembers[i].memberAddress);
        }

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(secondStreamId, 0);
        // Act
        uint256 secondGasStart = gasleft();
        vm.prank(secondCommitteeMembers[secondCommitteeMembers.length - 1].memberAddress);
        registry.depositAggregatedKey(secondCommitteeId, COMMITTEE_PUB_KEY());
        uint256 secondCommitteeGasUsed = secondGasStart - gasleft();

        // Assert
        uint256 absDifference = firstCommitteeGasUsed > secondCommitteeGasUsed
            ? firstCommitteeGasUsed - secondCommitteeGasUsed
            : secondCommitteeGasUsed - firstCommitteeGasUsed;
        uint256 percentageDifference = absDifference * 100 / firstCommitteeGasUsed;
        assertLt(
            percentageDifference,
            2,
            "Gas usage percentage difference between 10 and 100 candidates should be less than 2%"
        );
    }

    function test_createCommittee_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the createCommittee function for different candidates size
        // when choosing the last candidates as pending committee members
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 10:  1.68M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 1.69M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 200: 1.69M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 1.70M gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);
        uint256 candidatesSize = Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
        setup_registerNewMembers(candidatesSize, candidatesSize, denomination);

        // Create a pending committee with last candidates
        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        (CommitteeMember[] memory members, uint128 committeeId) =
            registry.createCommitteeWithLastCandidatesHarness(streamId, numWatchtowers, numOperators);

        assertEq(
            members.length,
            numWatchtowers + numOperators,
            "Members length should match the sum of operators and watchtowers"
        );

        for (uint256 i = 0; i < members.length - 1; i++) {
            setup_depositAggregatedKey(committeeId, members[i].memberAddress);
        }
        address lastMemberAddress = members[members.length - 1].memberAddress;

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(streamId, 0);

        // Act
        uint256 gasStart = gasleft();
        vm.prank(lastMemberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
        uint256 gasUsed = gasStart - gasleft();

        // Assert
        assertLt(gasUsed, MAX_GAS_PER_COMMITTEE_CREATION, "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION");
    }

    function test_stakePreStakedCandidatesBalance_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the stakePreStakedCandidatesBalanceHarness function
        // for different candidates size
        // when choosing the last candidates as pending committee members
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 10: 272K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 276K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 200: 280K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 282K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 282K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 292K gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 512: 293K gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);
        uint256 size = Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
        setup_registerNewMembers(size, size, denomination);

        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        (CommitteeMember[] memory members,) =
            registry.createCommitteeWithLastCandidatesHarness(streamId, numWatchtowers, numOperators);

        // Act
        uint256 gasStart = gasleft();
        registry.stakePreStakedCandidatesBalanceHarness(members, denomination, 0);
        uint256 gasUsed = gasStart - gasleft();

        // Assert
        assertLt(gasUsed, MAX_GAS_PER_COMMITTEE_CREATION, "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION");
    }

    function test_depositCommunicationData_Success() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberCommunicationDataDeposited(committeeId, memberAddress, communicationData);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - verify data was stored correctly using harness
        StreamDenomination expectedDenomination = StreamDenomination(expectedCommittee.streamId);
        CommunicationData[] memory storedData =
            registry.getStoredCommunicationDataHarness(expectedDenomination, memberAddress);

        assertCommunicationDataEqual(communicationData, storedData, "Stored data should match deposited data");
    }

    function test_depositCommunicationData_Success_MinData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create minimal communication data using helper function
        CommunicationData[] memory communicationData =
            createMinimalCommunicationData(expectedCommittee.members.length, memberIndex);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - verify minimal data was stored correctly
        StreamDenomination expectedDenomination = StreamDenomination(expectedCommittee.streamId);
        CommunicationData[] memory storedData =
            registry.getStoredCommunicationDataHarness(expectedDenomination, memberAddress);

        assertCommunicationDataEqual(communicationData, storedData, "Minimal data should be stored correctly");
    }

    function test_depositCommunicationData_Revert_MemberNotInCommittee() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        address nonMemberAddress = vm.addr(999); // Address not in committee
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommittee.members.length, 0);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, nonMemberAddress)
        );

        // Act
        vm.prank(nonMemberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_MemberNotInCommittee_butRegistered() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 privKey = 999;
        address registeredToAnotherStreamMemberAddress = vm.addr(privKey); // Address not in committee

        MemberRegistrationKeys memory publicKeysRegistration = generateRegistrationPublicKeys(privKey);

        setup_applyToStream(
            StreamDenomination._0_1BTC, registeredToAnotherStreamMemberAddress, publicKeysRegistration, Role.OPERATOR
        );
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommittee.members.length, 0);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, registeredToAnotherStreamMemberAddress
            )
        );

        // Act
        vm.prank(registeredToAnotherStreamMemberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_InvalidCommunicationDataLength() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        address memberAddress = vm.addr(1);

        // Create communication data with wrong length (committee size - 1)
        uint256 wrongLength = expectedCommittee.members.length - 1;
        CommunicationData[] memory wrongLengthData = new CommunicationData[](wrongLength);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidCommunicationDataLength.selector,
                wrongLength,
                expectedCommittee.members.length
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, wrongLengthData);
    }

    function test_depositCommunicationData_Revert_InvalidNonZeroCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create communication data with non-zero data in own slot (should be zero)
        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Put non-zero data in member's own slot
        communicationData[memberIndex].data[0] = bytes32(uint256(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidNonZeroCommunicationData.selector, memberIndex, communicationData[memberIndex]
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_InvalidZeroCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create communication data with zero data in another member's slot (should be non-zero)
        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Clear data for another member's slot (pick the first non-member slot)
        uint256 otherMemberIndex = memberIndex == 0 ? 1 : 0;
        for (uint256 i = 0; i < COMMUNICATION_DATA_CHUNKS; i++) {
            communicationData[otherMemberIndex].data[i] = bytes32(0);
        }

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroCommunicationData.selector,
                otherMemberIndex,
                communicationData[otherMemberIndex]
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_MemberAlreadyDepositedCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // First deposit should succeed
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - second deposit should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyDepositedCommunicationData.selector,
                committeeId,
                memberAddress,
                expectedCommittee.members.length
            )
        );

        // Act - try to deposit again
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_CommitteeIsNotPending() public {
        // Arrange
        uint64 noPendingCommitteeStreamId = 0; // Stream without pending committee
        address memberAddress = vm.addr(1);
        CommunicationData[] memory communicationData = new CommunicationData[](10); // Dummy data

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, noPendingCommitteeStreamId)
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(noPendingCommitteeStreamId, communicationData);
    }

    function test_depositCommunicationData_Success_AllMembersDeposit_EmitsAllCommunicationDataReady() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberCount = expectedCommittee.members.length;

        // Deposit all communication data except the last one
        for (uint256 i = 0; i < memberCount - 1; i++) {
            address memberAddress = expectedCommittee.members[i].memberAddress;
            CommunicationData[] memory communicationData = createValidCommunicationData(memberCount, i);

            vm.prank(memberAddress);
            registry.depositCommunicationData(committeeId, communicationData);
        }

        // Verify counter before final deposit
        uint16 missingCount = registry.getMissingCommunicationDataCount(committeeId);
        assertEq(missingCount, 1, "Should have 1 missing communication data before final deposit");

        // Prepare final member data
        address lastMemberAddress = expectedCommittee.members[memberCount - 1].memberAddress;
        CommunicationData[] memory lastCommunicationData = createValidCommunicationData(memberCount, memberCount - 1);

        // Assert that AllCommunicationDataReady event is emitted when the last member deposits
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AllCommunicationDataReady(committeeId);

        // Act - deposit the final communication data
        vm.prank(lastMemberAddress);
        registry.depositCommunicationData(committeeId, lastCommunicationData);

        // Assert counter is now zero
        uint16 finalMissingCount = registry.getMissingCommunicationDataCount(committeeId);
        assertEq(finalMissingCount, 0, "Should have 0 missing communication data after all deposits");
    }

    function test_depositCommunicationData_Revert_PendingCommitteeExpired() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Obtain the time of the committee's creation
        uint256 createdAt = expectedCommittee.createdAt;
        uint256 pendingCommitteeTimeout = registry.pendingCommitteeTimeout();
        uint256 expirationTime = createdAt + pendingCommitteeTimeout;

        // Advance the time until the committee expires
        vm.warp(expirationTime);

        // Assert - depositing in an expired committee must be reversed
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PendingCommitteeExpired.selector,
                committeeId,
                block.timestamp,
                createdAt,
                expirationTime
            )
        );

        // Act - attempt to deposit after expiration
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_getMemberCommunicationData_Success() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create expected communication data that other members should have deposited for this member
        CommunicationData[] memory expectedData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Use harness to simulate that all other members have deposited data for this member
        registry.setCommunicationDataForMemberHarness(expectedCommittee.streamId, memberIndex, expectedData);

        // Act
        vm.prank(memberAddress);
        CommunicationData[] memory retrievedData = registry.getMemberCommunicationData(committeeId, memberAddress);

        // Assert
        assertCommunicationDataEqual(expectedData, retrievedData, "Retrieved data should match expected data");
    }

    function test_getMemberCommunicationData_Revert_MemberNotInCommittee() public {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();

        uint256 privKey = 999;
        address memberAddressForOtherStream = vm.addr(privKey); // Address not in  pending committee
        MemberRegistrationKeys memory publicKeysRegistration = generateRegistrationPublicKeys(privKey);

        setup_applyToStream(
            StreamDenomination._0_1BTC, memberAddressForOtherStream, publicKeysRegistration, Role.OPERATOR
        );

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, memberAddressForOtherStream
            )
        );

        // Act
        vm.prank(memberAddressForOtherStream);
        registry.getMemberCommunicationData(committeeId, memberAddressForOtherStream);
    }

    function test_selectTakeOperator_Success_AllNoncesPresent_OperatorHasSignature() external {
        // Arrange - Test the condition: _missingNonces == 0 && _signatureData[operatorTakeIndex].signature.length > 0
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        // Create signature data array matching committee member order
        SignatureData[] memory signatureData = new SignatureData[](expectedCommittee.members.length);

        // Set up signature data: all members (both operators and watchtowers) have signatures and nonces
        bytes32 dummySignature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes memory dummyNonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        uint256 honestOperatorIndex = 2;
        for (uint256 i = 0; i < expectedCommittee.members.length; i++) {
            signatureData[i].nonce = dummyNonce; // All member added their nonces

            // Half of the members have signed
            if (i == honestOperatorIndex) {
                signatureData[i].signature = dummySignature;
            }
        }
        uint8 missingNonces = 0; // All nonces are present

        // Find the first operator index that signed
        uint256 expectedOpTakeIndex = honestOperatorIndex;

        address expectedOperator = expectedCommittee.members[expectedOpTakeIndex].memberAddress;
        bytes32 expectedDisputePubKey = getMemberDisputePubKey(expectedOperator);
        bytes32 expectedTakePubKey = memberRegistry.getMemberPublicKeys(expectedOperator).takePubKey;

        // Act - Call through operatorTakeManager since it's onlyPegManager
        vm.prank(address(operatorTakeManager));
        (address operatorAddress, bytes32 disputePubKey, bytes32 takePubKey) =
            registry.selectTakeOperator(committeeId, signatureData, missingNonces);

        // Assert
        assertEq(operatorAddress, expectedOperator, "Operator address should match expected");
        assertEq(disputePubKey, expectedDisputePubKey, "Dispute pub key should match expected");
        assertEq(takePubKey, expectedTakePubKey, "Take pub key should match expected");

        // Verify the operator take index was updated
        Committee memory updatedCommittee = registry.getCommittee(committeeId);
        assertEq(updatedCommittee.operatorTakeIndex, expectedOpTakeIndex, "Operator take index should be updated");
    }

    function test_selectTakeOperator_Success_MissingNonces_OperatorHasNonce() external {
        // Arrange - Test the condition: _missingNonces > 0 && _signatureData[operatorTakeIndex].nonce.length > 0
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        // Create signature data array matching committee member order
        SignatureData[] memory signatureData = new SignatureData[](expectedCommittee.members.length);

        // Set up signature data: only specific operators have nonces
        bytes memory dummyNonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Get current operator take index to know where to start
        uint256 currentOpTakeIndex = expectedCommittee.operatorTakeIndex;

        // Set up: Give nonce to a specific operator index that we know comes after operatorTakeIndex
        // We'll use index (currentOpTakeIndex + 2) to ensure we skip at least one position
        // But we need to make sure it's actually an operator, so we'll find the first operator after currentOpTakeIndex
        uint256 targetIndex = (currentOpTakeIndex + 1) % expectedCommittee.members.length;

        // Find first operator starting from targetIndex
        while (expectedCommittee.members[targetIndex].role != Role.OPERATOR) {
            signatureData[targetIndex].nonce = dummyNonce; // Add nonce to the non-operator member
            targetIndex = (targetIndex + 1) % expectedCommittee.members.length;
        }

        // Now we know targetIndex is an operator. Give nonce only to this operator
        signatureData[targetIndex].nonce = dummyNonce;
        // All other operators have empty nonces

        uint8 missingNonces = uint8(signatureData.length - 1); // Only 1 nonce

        // Expected operator is the one at targetIndex (the operator we gave nonce to)
        uint256 expectedOpTakeIndex = targetIndex;
        address expectedOperator = expectedCommittee.members[expectedOpTakeIndex].memberAddress;
        bytes32 expectedDisputePubKey = getMemberDisputePubKey(expectedOperator);
        bytes32 expectedTakePubKey = memberRegistry.getMemberPublicKeys(expectedOperator).takePubKey;

        // Act - Call through operatorTakeManager since it's onlyPegManager
        vm.prank(address(operatorTakeManager));
        (address operatorAddress, bytes32 disputePubKey, bytes32 takePubKey) =
            registry.selectTakeOperator(committeeId, signatureData, missingNonces);

        // Assert
        assertEq(operatorAddress, expectedOperator, "Operator address should match expected");
        assertEq(disputePubKey, expectedDisputePubKey, "Dispute pub key should match expected");
        assertEq(takePubKey, expectedTakePubKey, "Take pub key should match expected");

        // Verify the operator take index was updated
        Committee memory updatedCommittee = registry.getCommittee(committeeId);
        assertEq(updatedCommittee.operatorTakeIndex, expectedOpTakeIndex, "Operator take index should be updated");
    }

    function setup_signatureDataSingleNonce(Committee memory expectedCommittee)
        internal
        returns (SignatureData[] memory signatureData, uint256 targetIndex, uint8 missingNonces)
    {
        // Get current operator take index to know where to start
        uint256 currentOpTakeIndex = expectedCommittee.operatorTakeIndex;

        // Set up: Give nonce to a specific operator index that we know comes after operatorTakeIndex
        // We'll use index (currentOpTakeIndex + 1) to ensure we skip at least one position
        // But we need to make sure it's actually an operator, so we'll find the first operator after currentOpTakeIndex
        targetIndex = (currentOpTakeIndex + 1) % expectedCommittee.members.length;
        // Create signature data array matching committee member order
        signatureData = new SignatureData[](expectedCommittee.members.length);
        // Set up signature data: only specific operators have nonces
        bytes memory dummyNonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Find first operator starting from targetIndex
        while (expectedCommittee.members[targetIndex].role != Role.OPERATOR) {
            signatureData[targetIndex].nonce = dummyNonce; // Add nonce to the non-operator member
            targetIndex = (targetIndex + 1) % expectedCommittee.members.length;
        }

        // Now we know targetIndex is an operator. Give nonce only to this operator
        signatureData[targetIndex].nonce = dummyNonce;

        // All other operators have empty nonces
        missingNonces = uint8(signatureData.length - 1); // Only 1 nonce
    }

    function test_selectTakeOperator_Success_MissingNonces_OperatorRepicked() external {
        // Arrange - Test the condition: _missingNonces > 0 && _signatureData[operatorTakeIndex].nonce.length > 0
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        (SignatureData[] memory signatureData, uint256 targetIndex, uint8 missingNonces) =
            setup_signatureDataSingleNonce(expectedCommittee);

        // Expected operator is the one at targetIndex (the operator we gave nonce to)
        address expectedOperator = expectedCommittee.members[targetIndex].memberAddress;
        bytes32 expectedDisputePubKey = getMemberDisputePubKey(expectedOperator);
        bytes32 expectedTakePubKey = memberRegistry.getMemberPublicKeys(expectedOperator).takePubKey;

        // Select the operator that has the nonce - Call through operatorTakeManager since it's canSelectTakeOperator
        vm.prank(address(operatorTakeManager));
        (address operatorAddress1, bytes32 disputePubKey1, bytes32 takePubKey1) =
            registry.selectTakeOperator(committeeId, signatureData, missingNonces);

        // Act - Call through operatorTakeManager since it's canSelectTakeOperator
        // Repick the operator that has the nonce
        vm.prank(address(operatorTakeManager));
        (address operatorAddress2, bytes32 disputePubKey2, bytes32 takePubKey2) =
            registry.selectTakeOperator(committeeId, signatureData, missingNonces);

        // Assert
        assertEq(operatorAddress1, operatorAddress2, "Operator address should match expected repicked");
        assertEq(operatorAddress2, expectedOperator, "Operator address should match expected");
        assertEq(disputePubKey2, expectedDisputePubKey, "Dispute pub key should match expected");
        assertEq(disputePubKey1, disputePubKey2, "Dispute pub key should match expected repicked");
        assertEq(takePubKey1, takePubKey2, "Take pub key should match expected repicked");
        assertEq(takePubKey1, expectedTakePubKey, "Take pub key should match expected");

        // Verify the operator take index was updated
        Committee memory updatedCommittee = registry.getCommittee(committeeId);
        assertEq(updatedCommittee.operatorTakeIndex, targetIndex, "Operator take index should be updated");
    }

    function test_selectTakeOperator_Revert_TakeOperatorNotFound() external {
        // Arrange - No operators have nonces or signatures
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        // Create signature data array with empty nonces and signatures
        SignatureData[] memory signatureData = new SignatureData[](expectedCommittee.members.length);

        uint8 missingNonces = uint8(expectedCommittee.members.length); // All nonces are missing

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TakeOperatorNotFound.selector, committeeId));

        // Act - Call through operatorTakeManager since it's canSelectTakeOperator
        vm.prank(address(operatorTakeManager));
        registry.selectTakeOperator(committeeId, signatureData, missingNonces);
    }

    function test_validateMemberInCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();
        address memberAddress = expectedCommittee.members[0].memberAddress;

        // Act & Assert - should not revert
        vm.prank(memberAddress);
        registry.validateMemberInCommittee(committeeId, memberAddress);
    }

    function test_validateMemberInCommittee_Reverts_WrongAddress() external {
        // Arrange
        (, uint128 committeeId) = setup_completeCommittee();
        address nonMemberAddress = vm.addr(999); // Address not in committee

        // Act & Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, nonMemberAddress)
        );
        vm.prank(nonMemberAddress);
        registry.validateMemberInCommittee(committeeId, nonMemberAddress);
    }

    function test_validateMemberInCommittee_Reverts_WrongCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();
        address memberAddress = expectedCommittee.members[0].memberAddress;
        uint128 wrongCommitteeId = committeeId + 1; // Non-existent committee

        // Act & Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, wrongCommitteeId, memberAddress)
        );
        vm.prank(memberAddress);
        registry.validateMemberInCommittee(wrongCommitteeId, memberAddress);
    }

    // ==================== TESTNET ONLY FUNCTION TESTS ====================

    function test_forceDiscardPendingCommittee_TESTNET_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        address unauthorizedAccount = address(0x1234);
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorizedAccount));

        // Act
        vm.prank(unauthorizedAccount);
        registry.forceDiscardPendingCommittee_TESTNET(streamId);
    }

    function test_forceDiscardPendingCommittee_TESTNET_Revert_TestnetOnlyFunction() external {
        // Arrange
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;
        address owner = registry.owner();

        // Simulate RSK mainnet (chain ID 30)
        vm.chainId(30);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.TestnetOnlyFunction.selector));

        // Act
        vm.prank(owner);
        registry.forceDiscardPendingCommittee_TESTNET(streamId);
    }

    // ==================== END TESTNET ONLY FUNCTION TESTS ====================
}
