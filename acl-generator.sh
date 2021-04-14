#!/usr/bin/env bash
# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

# get arguments
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    --zookeeper-host)
    ZOOKEEPER="$2"
    shift # past argument
    ;;
    --file)
    INPUTFILE="$2"
    shift # past argument
    ;;
    --help)
    print_help
    ;;
    *)
    print_help
    ;;
esac
shift # past argument or value
done

print_help() {
  echo "Takes output of kafka-acls --list as STDIN or from a file, and outputs kafka-acls commands to be used to migrate ACLs:"
  echo "$0 --zookeeper-host <ZK>:2181 [--file <input-file>]"
  exit 1
}

# No Zookeeper specified, exit
if [[ -z "${ZOOKEEPER}" ]]; then
  echo "ERROR: No zookeeper specified"
  print_help
fi

# No input file flag, use STDIN
if [[ -z "${INPUTFILE}" ]]; then
  echo "ERROR: no input acl file specified"
  print_help
fi


#Current ACLs for resource `ResourcePattern(resourceType=GROUP, name=AccrualDateProcessor, patternType=LITERAL)`:
#        (principal=User:srvAP136959NP, host=*, operation=DESCRIBE, permissionType=ALLOW)
#        (principal=User:srvAP136959NP, host=*, operation=READ, permissionType=ALLOW)
#        (principal=User:srvpr173418-daf-np, host=*, operation=READ, permissionType=ALLOW)
#        (principal=User:srvpr173418-daf-np, host=*, operation=DESCRIBE, permissionType=ALLOW)
        
# Read the file line by line
while read LINE || [[ -n ${LINE} ]];do
  # If the line is empty this is the end of the resource
  if [[ -z $LINE ]]; then
    continue
  fi

  # if we see that line begins with "Current" this is the beginning
  # of a resource
  if [[ "${LINE}" == "Current"* ]]; then
    RESOURCE=$(echo "${LINE}"| awk -F \` '{print $2}' | awk -F resourceType= '{print $2}' | awk -F , '{print $1}')
    RESOURCE_NAME=$(echo "${LINE}"| awk -F \` '{print $2}' | awk -F name= '{print $2}' | awk -F , '{print $1}')
    # Figure out the resource flag
    case "${RESOURCE}" in
      TOPIC )
        RESOURCE_FLAG="--topic"
        ;;
      GROUP )
        RESOURCE_FLAG="--group"
        ;;
      CLUSTER )
        RESOURCE_FLAG="--cluster"
        ;;
      * )
        echo "ERROR: unrecognized resource flag!"
        exit 1
        ;;
    esac
  else
    # These are the permissions for the resource
    PRINCIPAL=$(echo "${LINE}" | awk -F principal= '{print $2}' | awk -F , '{print $1}')
    PERMISSION=$(echo "${LINE}" | awk -F permissionType= '{print $2}' | awk -F \) '{print $1}')
    OPERATION=$(echo "${LINE}"|  awk -F operation= '{print $2}' | awk -F , '{print $1}' | tr '[:upper:]' '[:lower:]')
    HOSTS=$(echo "${LINE}"| awk -F host= '{print $2}' | awk -F , '{print $1}')

    # Figure out the permission flag
    case "${PERMISSION}" in
      ALLOW )
        PERMISSION_FLAG="--allow-principal"
        HOST_PERMISSION_FLAG="--allow-host"
        ;;
      DENY )
        PERMISSION_FLAG="--deny-principal"
        HOST_PERMISSION_FLAG="--deny-host"
        ;;
    esac
    if [[ -z $PRINCIPAL ]] || [[ -z $PERMISSION ]] || [[ -z $OPERATION ]] || [[ -z $HOSTS ]]; then
      echo "ERROR: parsing error at ${LINE}"
      exit 1
    fi
    
    echo "kafka-acls --authorizer-properties zookeeper.connect=${ZOOKEEPER} --add ${PERMISSION_FLAG} ${PRINCIPAL} ${HOST_PERMISSION_FLAG} ${HOSTS} --operation ${OPERATION} ${RESOURCE_FLAG} ${RESOURCE_NAME}"
  fi
done <${INPUTFILE}

