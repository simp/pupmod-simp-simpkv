#!/bin/sh
docker pull consul
docker run -d -p "8500:8500" -p "8501:8501" -v "$(pwd):/vagrant" -e CONSUL_LOCAL_CONFIG='{ "addresses": { "https":"0.0.0.0" }, "ports" : { "https" : 8501 }, "key_file" : "/vagrant/test/server.key", "cert_file" : "/vagrant/test/server.crt", "ca_file" : "/vagrant/test/ca.crt"}' consul:0.8.0
docker run -d -p "8504:8500" -p "8503:8501" -v "$(pwd):/vagrant" -e CONSUL_LOCAL_CONFIG='{ "addresses": { "https":"0.0.0.0" }, "ports" : { "https" : 8501 }, "key_file" : "/vagrant/test/server.key", "cert_file" : "/vagrant/test/server.crt", "ca_file" : "/vagrant/test/ca.crt", "verify_incoming": true}' consul:0.8.0
sleep 5
for i in $(docker ps -aq)
do
  docker inspect "${i}"
  docker logs "${i}"
done
curl -kvvvv https://172.17.0.1:8501
curl -kvvvv --cacert test/ca.pem --cert test/server.crt --key test/server.key https://172.17.0.1:8503
