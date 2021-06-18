function usage()
{
    echo "Usage: build.sh [SE] SOFTWARE_ENCRYPTION_KEY PCE_USER_PASSWORD"
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
  if [[ -n $RUNSEMODE ]]; then
    docker run -it -p 8443:8443 -p 8444:8444 -e ILLUMIO_ACCEPT_EULA=true -e PCE_PASSWORD=$PCE_PASSWORD -e KEY=$ENC_KEY -e SE=$1 --hostname pce.test.local --name pce illumio-docker-pce
  else
    docker run -it -p 8443:8443 -p 8444:8444 -e ILLUMIO_ACCEPT_EULA=true -e PCE_PASSWORD=$PCE_PASSWORD -e KEY=$ENC_KEY --hostname pce.test.local --name pce illumio-docker-pce
  fi
}

if [[ $1 == "SE" || $1 == "se" ]]; then
  if ! [[ -e software/se.txt ]]; then
    echo "You are asking for SE setup with no SE setup."
    echo "software/se.txt file is missing."
    echo "This script is looking for two variables in this file, each on a separate line:"
    echo "ENC_KEY=[any encryption key] and PCE_PASSWORD=[demo user password]"
    echo "Set these in software/se.txt and rerun this script."
    exit 1
  fi
  ENC_KEY=`grep -E "ENC_KEY" software/se.txt | sed 's/^.*=//'`
  PCE_PASSWORD=`grep -E "PCE_PASSWORD" software/se.txt | sed 's/^.*=//'`
  RUNSEMODE=YES
elif [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
  usage
else
  ENC_KEY=$1
  PCE_PASSWORD=$2
fi

echo "$ENC_KEY is the encryption key used in the build process."
echo "$PCE_PASSWORD will be the password used in the build process."

killdocker
builddocker

if [[ -n RUNSEMODE ]]; then
  rundocker SE
else
  rundocker
fi

exit 0