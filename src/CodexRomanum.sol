// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {VeilStorage} from "./libraries/VeilStorage.sol";

contract CodexRomanum is Initializable, AccessControlUpgradeable {
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");

    event InvariantRegistered(bytes32 indexed invariantId, uint8 indexed invariantType, address indexed subject);
    event RouteConfigured(address indexed adapter, bool enabled, bool shadowOnAlert, bool requireProof);

    function initialize(address admin, address senate) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SENATE_ROLE, senate);
    }

    function setInvariant(bytes32 invariantId, PraetorianTypes.Invariant calldata invariant_) external onlyRole(SENATE_ROLE) {
        VeilStorage.CodexLayout storage s = VeilStorage.codex();
        s.invariants[invariantId] = invariant_;

        if (!s.knownInvariant[invariantId]) {
            s.knownInvariant[invariantId] = true;
            s.invariantIds.push(invariantId);
        }

        emit InvariantRegistered(invariantId, invariant_.invariantType, invariant_.subject);
    }

    function setRoute(address adapter, PraetorianTypes.RouteConfig calldata config) external onlyRole(SENATE_ROLE) {
        VeilStorage.codex().routes[adapter] = config;
        emit RouteConfigured(adapter, config.enabled, config.shadowOnAlert, config.requireProof);
    }

    function routeConfig(address adapter) external view returns (PraetorianTypes.RouteConfig memory) {
        return VeilStorage.codex().routes[adapter];
    }

    function invariantCount() external view returns (uint256) {
        return VeilStorage.codex().invariantIds.length;
    }

    function invariantAt(
        uint256 index
    ) external view returns (bytes32 id, PraetorianTypes.Invariant memory invariant_) {
        VeilStorage.CodexLayout storage s = VeilStorage.codex();
        id = s.invariantIds[index];
        invariant_ = s.invariants[id];
    }
}
