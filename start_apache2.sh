#!/bin/bash

. /etc/apache2/envvars
exec apache2 -DFOREGROUND
