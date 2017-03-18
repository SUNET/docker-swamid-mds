#!/bin/sh -x

printenv

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR

if [ ! -f "$KEYDIR/private/${PUBLIC_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${PUBLIC_HOSTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${PUBLIC_HOSTNAME}.crt"
fi

CHAINSPEC=""
export CHAINSPEC
if [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.chain" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.chain"
elif [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}-chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}-chain.crt"
elif [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.chain.crt"
elif [ -f "$KEYDIR/certs/chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.crt"
elif [ -f "$KEYDIR/certs/chain.pem" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.pem"
fi

echo "${PUBLIC_HOSTNAME}" > /var/www/_lvs.txt

cat>/etc/apache2/sites-available/default.conf<<EOF
<VirtualHost _default_:80>
       ServerAdmin operations@swamid.se
       DocumentRoot /var/www/
       ServerName ${PUBLIC_HOSTNAME}
       ServerAlias ${PUBLIC_HOSTNAMES}

       ProxyPass /.well-known/acme-challenge/ http://acme-c.sunet.se/.well-known/acme-challenge/
       ProxyPassReverse /.well-known/acme-challenge/ http://acme-c.sunet.se/.well-known/acme-challenge/

       RewriteEngine on
       RewriteRule "^/\$" "/md/" [R]
       RewriteCond "%{HTTP_HOST}" "^(.+)\$"
       RewriteRule "^/md/(.*)\$" "/opt/published-metadata/%1/\$1"

       <Directory /opt/published-metadata>
          Require all granted
          Options Indexes FollowSymLinks
       </Directory>
       Alias /xslt /opt/swamid-metadata/xslt/
        <Directory /opt/swamid-metadata/xslt>
          Require all granted
          Options Indexes FollowSymLinks
        </Directory>
       <Directory /var/www>
          Require all granted
          Options -Indexes +FollowSymLinks
       </Directory>
</VirtualHost>
ExtendedStatus On
EOF

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
ServerName ${PUBLIC_HOSTNAME}
<VirtualHost *:443>
        ServerName ${PUBLIC_HOSTNAME}
        ServerAlias ${PUBLIC_HOSTNAMES}
        SSLProtocol All -SSLv2 -SSLv3
        SSLCompression Off
        SSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+AESGCM EECDH EDH+AESGCM EDH+aRSA HIGH !MEDIUM !LOW !aNULL !eNULL !LOW !RC4 !MD5 !EXP !PSK !SRP !DSS"
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.crt
        ${CHAINSPEC}
        SSLCertificateKeyFile $KEYDIR/private/${PUBLIC_HOSTNAME}.key
        DocumentRoot /var/www/
        
        ServerAdmin operations@swamid.se

        AddDefaultCharset utf-8

        ServerSignature off

       ProxyPass /.well-known/acme-challenge/ http://acme-c.sunet.se/.well-known/acme-challenge/
       ProxyPassReverse /.well-known/acme-challenge/ http://acme-c.sunet.se/.well-known/acme-challenge/

       RewriteEngine on
       RewriteRule "^/\$" "/md/" [R]
       RewriteCond "%{HTTP_HOST}" "^(.+)\$"
       RewriteRule "^/md/(.*)\$" "/opt/published-metadata/%1/\$1"

       <Directory /opt/published-metadata>
          Require all granted
          Options Indexes FollowSymLinks
       </Directory>
       Alias /xslt /opt/swamid-metadata/xslt/
        <Directory /opt/swamid-metadata/xslt>
          Require all granted
          Options Indexes FollowSymLinks
        </Directory>
       <Directory /var/www>
          Require all granted
          Options -Indexes +FollowSymLinks
       </Directory>
</VirtualHost>
EOF

cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl
a2enmod proxy proxy_http

rm -f /var/run/apache2/apache2.pid

mkdir -p /var/lock/apache2 /var/run/apache2
env APACHE_LOCK_DIR=/var/lock/apache2 APACHE_RUN_DIR=/var/run/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 apache2 -DFOREGROUND
