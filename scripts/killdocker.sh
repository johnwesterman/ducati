echo "Removing the container environment."
docker rm -f $(docker ps -a -q -f name=pce)
docker rmi illumio-docker-pce:latest
docker volume rm $(docker volume ls -q)
exit 0