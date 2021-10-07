
openssl ecparam -genkey -name prime256v1 -out caca.key
openssl req -x509 -new -SHA384 -nodes -key caca.key -days 3650 -out caca.crt -subj "/C=UF/ST=/L=/O=United Federation of Planets/OU=/CN=HD26965b CA/emailAddress="

sudo mkdir /usr/local/share/ca-certificates/extra
sudo cp caca.crt /usr/local/share/ca-certificates/extra/
sudo update-ca-certificates
