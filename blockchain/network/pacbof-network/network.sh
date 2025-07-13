#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script brings up a Hyperledger Fabric network for testing smart contracts
# and applications. The test network consists of two organizations with one
# peer each, and a single node Raft ordering service. Users can also use this
# script to create a channel deploy a chaincode on the channel
#

# Ensure we're in the right directory and set paths
ROOTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH=${ROOTDIR}/../bin:${ROOTDIR}/scripts:${PATH}
export FABRIC_CFG_PATH=${ROOTDIR}/configtx # Updated to use relative path within project
export VERBOSE=false

# Source the utility scripts
# These will be created next
. ${ROOTDIR}/scripts/utils.sh
. ${ROOTDIR}/scripts/envVar.sh
. ${ROOTDIR}/scripts/ccutils.sh

# Docker/Podman compatibility
: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Obtain CONTAINER_IDS and remove them
function clearContainers() {
  infoln "Removing remaining containers"
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
  ${CONTAINER_CLI} kill "$(${CONTAINER_CLI} ps -q --filter name=ccaas)" 2>/dev/null || true
}

# Delete any images that were generated as a part of this setup
function removeUnwantedImages() {
  infoln "Removing generated chaincode docker images"
  ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

# Versions of fabric known not to work with the test network
NONWORKING_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available.
function checkPrereqs() {
  ## Check if your have cloned the peer binaries and configuration files.
  peer version > /dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    errorln "Peer binary and configuration files not found or not accessible."
    errorln "Please ensure Hyperledger Fabric binaries (peer, configtxgen, cryptogen) are installed in your system's PATH."
    errorln "Refer to 'Development Environment Setup' in README.md"
    exit 1
  fi
  # Use the fabric peer container to see if the samples and binaries match your
  # docker images
  # LOCAL_VERSION=$(peer version | sed -ne 's/^ Version: //p')
  # DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-peer:latest peer version | sed -ne 's/^ Version: //p')

  # infoln "LOCAL_VERSION=$LOCAL_VERSION"
  # infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  # if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
  #   warnln "Local fabric binaries and docker images are out of sync. This may cause problems."
  # fi

  for UNSUPPORTED_VERSION in $NONWORKING_VERSIONS; do
    infoln "$(peer version 2>/dev/null | grep Version | cut -d' ' -f2)" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Local Fabric binary version is not supported by this network configuration."
    fi

    # Check docker image version if available
    # ${CONTAINER_CLI} images hyperledger/fabric-peer:latest &> /dev/null
    # if [ $? -eq 0 ]; then
    #   infoln "$(${CONTAINER_CLI} run --rm hyperledger/fabric-peer:latest peer version | sed -ne 's/^ Version: //p')" | grep -q $UNSUPPORTED_VERSION
    #   if [ $? -eq 0 ]; then
    #     fatalln "Fabric Docker image version is not supported by this network configuration."
    #   fi
    # fi
  done

  ## check for fabric-ca
  # if [ "$CRYPTO" == "Certificate Authorities" ]; then
  #   fabric-ca-client version > /dev/null 2>&1
  #   if [[ $? -ne 0 ]]; then
  #     errorln "fabric-ca-client binary not found.."
  #     errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries: https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
  #     exit 1
  #   fi
  #   CA_LOCAL_VERSION=$(fabric-ca-client version | sed -ne 's/ Version: //p')
  #   CA_DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-ca:latest fabric-ca-client version | sed -ne 's/ Version: //p' | head -1)
  #   infoln "CA_LOCAL_VERSION=$CA_LOCAL_VERSION"
  #   infoln "CA_DOCKER_IMAGE_VERSION=$CA_DOCKER_IMAGE_VERSION"
  #   if [ "$CA_LOCAL_VERSION" != "$CA_DOCKER_IMAGE_VERSION" ]; then
  #     warnln "Local fabric-ca binaries and docker images are out of sync. This may cause problems."
  #   fi
  # fi
}

# Create Organization crypto material using cryptogen
function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  # Default to cryptogen for now
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found. Please install Fabric binaries."
    }
    infoln "Generating certificates using cryptogen tool"

    infoln "Creating Org1 Identities"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org1.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate Org1 certificates..."
    fi

    infoln "Creating Org2 Identities"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-org2.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate Org2 certificates..."
    fi

    infoln "Creating Orderer Org Identities"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate Orderer certificates..."
    fi

  # Add Fabric CA generation here later if needed
  # elif [ "$CRYPTO" == "Certificate Authorities" ]; then
  #   infoln "Generating certificates using Fabric CA"
  #   ${CONTAINER_CLI_COMPOSE} -f compose/${COMPOSE_FILE_CA} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA} up -d 2>&1
  #   . organizations/fabric-ca/registerEnroll.sh
  #   createOrg1
  #   createOrg2
  #   createOrderer
  fi

  infoln "Generating CCP files for Org1 and Org2"
  # Placeholder for ccp-generate script, will be created later
  # ./organizations/ccp-generate.sh
  infoln "CCP file generation placeholder."
}

# Bring up the peer and orderer nodes using docker compose.
function networkUp() {
  checkPrereqs

  # generate artifacts if they don't exist
  if [ ! -d "organizations/peerOrganizations" ]; then
    createOrgs
  fi

  # Generate genesis block if it doesn't exist
  if [ ! -f "channel-artifacts/genesis.block" ]; then
    infoln "Generating orderer genesis block"
    set -x
    configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate orderer genesis block..."
    fi
  fi

  COMPOSE_FILES="-f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"

  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  fi

  infoln "Starting network containers..."
  DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1

  $CONTAINER_CLI ps -a
  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi
}

# call the script to create the channel, join the peers of org1 and org2,
# and then update the anchor peers for each organization
function createChannel() {
  # Bring up the network if it is not already up.
  bringUpNetwork="false"

  if ! $CONTAINER_CLI info > /dev/null 2>&1 ; then
    fatalln "$CONTAINER_CLI network is required to be running to create a channel"
  fi

  # Check if containers are running
  CONTAINERS=$(${CONTAINER_CLI} ps -q --filter label=service=hyperledger-fabric)
  if [ -z "$CONTAINERS" ]; then
    infoln "No Fabric containers running. Bringing up network first."
    networkUp
  else
    infoln "Fabric containers already running. Skipping 'networkUp'."
  fi

  # Now run the script that creates a channel. This script uses configtxgen once
  # to create the channel creation transaction and the anchor peer updates.
  ${ROOTDIR}/scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
}


## Call the script to deploy a chaincode to the channel
function deployCC() {
  ${ROOTDIR}/scripts/deployCC.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE

  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode failed"
  fi
}

## Call the script to deploy a chaincode to the channel (Chaincode-as-a-Service)
function deployCCAAS() {
  ${ROOTDIR}/scripts/deployCCAAS.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CCAAS_DOCKER_RUN $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE $CCAAS_DOCKER_RUN

  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode-as-a-service failed"
  fi
}

## Call the script to package the chaincode
function packageChaincode() {
  infoln "Packaging chaincode"
  ${ROOTDIR}/scripts/packageCC.sh $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION true
  if [ $? -ne 0 ]; then
    fatalln "Packaging the chaincode failed"
  fi
}

## Call the script to list installed and committed chaincode on a peer
function listChaincode() {
  # Set environment for the peer to execute the command
  export FABRIC_CFG_PATH=${ROOTDIR}/config # Ensure this points to correct config path

  . ${ROOTDIR}/scripts/envVar.sh
  . ${ROOTDIR}/scripts/ccutils.sh

  setGlobals $ORG # ORG should be passed as an argument or set in network.config

  println
  queryInstalledOnPeer
  println

  listAllCommitted
}

## Call the script to invoke chaincode
function invokeChaincode() {
  export FABRIC_CFG_PATH=${ROOTDIR}/config # Ensure this points to correct config path

  . ${ROOTDIR}/scripts/envVar.sh
  . ${ROOTDIR}/scripts/ccutils.sh

  setGlobals $ORG
  chaincodeInvoke $ORG $CHANNEL_NAME $CC_NAME $CC_INVOKE_CONSTRUCTOR
}

## Call the script to query chaincode
function queryChaincode() {
  export FABRIC_CFG_PATH=${ROOTDIR}/config # Ensure this points to correct config path

  . ${ROOTDIR}/scripts/envVar.sh
  . ${ROOTDIR}/scripts/ccutils.sh

  setGlobals $ORG
  chaincodeQuery $ORG $CHANNEL_NAME $CC_NAME $CC_QUERY_CONSTRUCTOR
}


# Tear down running network
function networkDown() {
  local temp_compose=$COMPOSE_FILE_BASE
  COMPOSE_FILE_BASE=docker-compose-test-net.yaml # Ensure we reference the correct base file
  COMPOSE_BASE_FILES="-f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"
  COMPOSE_COUCH_FILES="-f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  COMPOSE_CA_FILES="-f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA}"
  COMPOSE_FILES="${COMPOSE_BASE_FILES} ${COMPOSE_COUCH_FILES} ${COMPOSE_CA_FILES}"

  # stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
  # COMPOSE_ORG3_BASE_FILES="-f addOrg3/compose/${COMPOSE_FILE_ORG3_BASE} -f addOrg3/compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_ORG3_BASE}"
  # COMPOSE_ORG3_COUCH_FILES="-f addOrg3/compose/${COMPOSE_FILE_ORG3_COUCH} -f addOrg3/compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_ORG3_COUCH}"
  # COMPOSE_ORG3_CA_FILES="-f addOrg3/compose/${COMPOSE_FILE_ORG3_CA} -f addOrg3/compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_ORG3_CA}"
  # COMPOSE_ORG3_FILES="${COMPOSE_ORG3_BASE_FILES} ${COMPOSE_ORG3_COUCH_FILES} ${COMPOSE_ORG3_CA_FILES}"


  if [ "${CONTAINER_CLI}" == "docker" ]; then
    DOCKER_SOCK=$DOCKER_SOCK ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
  elif [ "${CONTAINER_CLI}" == "podman" ]; then
    ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes
  else
    fatalln "Container CLI  ${CONTAINER_CLI} not supported"
  fi

  COMPOSE_FILE_BASE=$temp_compose

  # Don't remove the generated artifacts -- note, the ledgers are always removed
  if [ "$MODE" != "restart" ]; then
    # Bring down the network, deleting the volumes
    # Use careful regex to remove only relevant volumes
    ${CONTAINER_CLI} volume rm $(${CONTAINER_CLI} volume ls -q --filter name='compose_peer0.org[12].example.com') 2>/dev/null || true
    ${CONTAINER_CLI} volume rm $(${CONTAINER_CLI} volume ls -q --filter name='compose_orderer.example.com') 2>/dev/null || true

    #Cleanup the chaincode containers and images
    clearContainers
    removeUnwantedImages

    # remove orderer block and other channel configuration transactions and certs
    # Use the project's organizations and channel-artifacts paths
    rm -rf organizations/peerOrganizations organizations/ordererOrganizations channel-artifacts/* system-genesis-block/* 2>/dev/null || true
    # Remove CA artifacts if any (placeholders for now)
    # rm -rf organizations/fabric-ca/* 2>/dev/null || true

    # remove channel and script artifacts
    rm -f log.txt *.tar.gz 2>/dev/null || true
  fi
}

# --- Network Configuration Variables (Loaded from network.config) ---
# Load default variables from network.config
. ./network.config # This needs to be present in the same directory

# use this as the default docker compose yaml definition
COMPOSE_FILE_BASE=docker-compose-test-net.yaml # Ensure this matches the file we created
# docker compose.yaml file if you are using couchdb
COMPOSE_FILE_COUCH=docker-compose-couch.yaml # Will create later
# certificate authorities compose file
COMPOSE_FILE_CA=docker-compose-ca.yaml # Will create later

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

# BFT activated flag (set to 0 for now)
BFT=0

# Print help function
function printHelp() {
  println "Usage: "
  println "  network.sh <Mode> [Flags]"
  println "    Modes:"
  println "      up                 - Bring up Fabric orderer and peer nodes. No channel is created."
  println "      createChannel      - Create and join a channel after the network is created."
  println "      deployCC           - Deploy a chaincode to a channel (patient-consent)."
  println "      cc                 - Chaincode functions, use "network.sh cc -h" for options."
  println "      down               - Bring down the network."
  println "    Flags:"
  println "    -c <channel name>  - Name of channel to create (defaults to "mychannel")"
  println "    -s <dbtype>        - Peer state database to deploy: goleveldb (default) or couchdb"
  println "    -r <max retry>     - CLI times out after certain number of attempts (defaults to 5)"
  println "    -d <delay>         - CLI delays for a certain number of seconds (defaults to 3)"
  println "    -ccn <name>        - Chaincode name (defaults to patient-consent)"
  println "    -ccp <path>        - File path to the chaincode (defaults to blockchain/chaincode/patient-consent/go)"
  println "    -ccl <language>    - Programming language of the chaincode (defaults to go)"
  println "    -ccv <version>     - Chaincode version (defaults to 1.0)"
  println "    -ccs <sequence>    - Chaincode definition sequence (defaults to auto)"
  println "    -cci <fcn name>    - Chaincode initialization function (defaults to InitLedger)"
  println "    -ccep <policy>     - Chaincode endorsement policy (defaults to OR('Org1MSP.peer','Org2MSP.peer'))"
  println "    -verbose           - Verbose mode"
  println "    -h                 - Print this message"
  println
  println " Examples:"
  println "   network.sh up"
  println "   network.sh createChannel -c mychannel"
  println "   network.sh deployCC -ccn patient-consent -ccp ../chaincode/patient-consent/go -ccl go -cci InitLedger -ccep "OR('Org1MSP.peer','Org2MSP.peer')""
  println "   network.sh cc invoke -org 1 -c mychannel -ccn patient-consent -ccic '{"Args":["CreateConsent","consent1","patient123","doctor456","["medical-history","lab-results"]","["read","share"]","treatment","365"]}'"
  println "   network.sh cc query -org 1 -c mychannel -ccn patient-consent -ccqc '{"Args":["GetAllConsents"]}'"
  println "   network.sh down"
}

# Parse commandline args
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

# if no parameters are passed, show the help for cc
if [ "$MODE" == "cc" ] && [[ $# -lt 1 ]]; then
  printHelp $MODE
  exit 0
fi

# parse subcommands if used
if [[ $# -ge 1 ]] ; then
  key="$1"
  # check for the createChannel subcommand
  if [[ "$key" == "createChannel" ]]; then
      export MODE="createChannel"
      shift
  # check for the cc command
  elif [[ "$MODE" == "cc" ]]; then
    if [ "$1" != "-h" ]; then
      export SUBCOMMAND=$key
      shift
    fi
  fi
fi

# Parse flags
while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp $MODE
    exit 0
    ;;
  -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -s )
    DATABASE="$2"
    shift
    ;;
  -r )
    MAX_RETRY="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -ccl )
    CC_SRC_LANGUAGE="$2"
    shift
    ;;
  -ccn )
    CC_NAME="$2"
    shift
    ;;
  -ccv )
    CC_VERSION="$2"
    shift
    ;;
  -ccs )
    CC_SEQUENCE="$2"
    shift
    ;;
  -ccp )
    CC_SRC_PATH="$2"
    shift
    ;;
  -ccep )
    CC_END_POLICY="$2"
    shift
    ;;
  -cccg )
    CC_COLL_CONFIG="$2"
    shift
    ;;
  -cci )
    CC_INIT_FCN="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    ;;
  -org )
    ORG="$2"
    shift
    ;;
  -ccic )
    CC_INVOKE_CONSTRUCTOR="$2"
    shift
    ;;
  -ccqc )
    CC_QUERY_CONSTRUCTOR="$2"
    shift
    ;;
  * )
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

# Set defaults if not provided by flags
: ${CHANNEL_NAME:="mychannel"}
: ${CLI_DELAY:=3}
: ${MAX_RETRY:=5}
: ${CC_NAME:="patient-consent"} # Default chaincode name
: ${CC_SRC_PATH:="blockchain/chaincode/patient-consent/go"} # Default chaincode path
: ${CC_SRC_LANGUAGE:="go"} # Default chaincode language
: ${CC_VERSION:="1.0"} # Default chaincode version
: ${CC_SEQUENCE:="1"} # Default sequence to 1 initially for new deployment
: ${CC_INIT_FCN:="InitLedger"} # Default init function
: ${CC_END_POLICY:="OR('Org1MSP.peer','Org2MSP.peer')"} # Default endorsement policy
: ${DATABASE:="leveldb"} # Default peer database

# Define operations based on MODE
if [ "$MODE" == "up" ]; then
  infoln "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}'"
  networkUp
elif [ "$MODE" == "createChannel" ]; then
  infoln "Creating channel '${CHANNEL_NAME}'."
  createChannel
elif [ "$MODE" == "down" ]; then
  infoln "Stopping network"
  networkDown
elif [ "$MODE" == "deployCC" ]; then
  infoln "Deploying chaincode on channel '${CHANNEL_NAME}'"
  deployCC
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "package" ]; then
  packageChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "list" ]; then
  listChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "invoke" ]; then
  invokeChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "query" ]; then
  queryChaincode
else
  printHelp
  exit 1
fi
