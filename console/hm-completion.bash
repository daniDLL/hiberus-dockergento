#!/usr/bin/env bash

if [[ $SHELL == "/bin/sh" ]]; then
    exit
fi

complete -W "bash \ 
cloud-login \ 
cloud \ 
compatibility \ 
composer \ 
config-env \ 
copy-from-container \ 
copy-to-container \ 
create-project \ 
debug-off \ 
debug-on \ 
docker-compose \ 
docker-stop-all \ 
down \ 
exec \ 
grunt \ 
install \ 
magento \ 
mysql \ 
mysqldump \ 
n98-magerun \ 
npm \ 
purge \ 
rebuild \ 
restart \ 
set-host \ 
setup \ 
ssl \ 
start \ 
stop \ 
test-integration \ 
test-unit \ 
transfer-db \ 
transfer-media \ 
update \ 
varnish-off \ 
varnish-on \ 
" hm
