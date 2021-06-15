function usage()
{
    echo "Usage: build.sh [SE] PCE_USER_PASSWORD KEY"
    exit 1
}

function killdocker()
{
  echo "Removing the container environment."
  docker rm -f $(docker ps -a -q -f name=pce)
  docker rmi illumio-docker-pce:latest
  docker volume rm $(docker volume ls -q)
}

function builddocker ()
{
  echo "Building the image."
  docker build --tag illumio-docker-pce .
}

function rundocker ()
{
  echo "Running the container."
  docker run -it -p 8443:8443 -p 8444:8444 -e ILLUMIO_ACCEPT_EULA=true -e PCE_PASSWORD=$PCE_PASSWORD -e KEY=$ENC_KEY -e SE=$1 --hostname pce.test.local --name pce illumio-docker-pce
}

if [[ $1 == "SE" || $1 == "se" ]]; then
  ENC_KEY=TESTKEY
  PCE_PASSWORD=Illumio123
  RUNSEMODE=YES
elif [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
  usage
else
  ENC_KEY=$1
  PCE_PASSWORD=$2
fi

killdocker
builddocker

if [[ -n RUNSEMODE ]]; then
  rundocker SE
else
  rundocker
fi

exit 0