#!/bin/sh
#
# Create a proxy pass with nginx or Apache2
# <piolet.y@gmail.com>


NGINX_SITES="/etc/nginx/sites-available"
NGINX_EN="/etc/nginx/sites-enabled"
PPIP=127.0.0.1
echo "Enter host [127.0.0.1]"
read PPIP
echo "Enter port"
read PPPORT
echo "Enter hostname (ex: vhost.example.com)"
read PPHOSTNAME
echo "Enter config name (ex: vhost)"
read PPCONFIG

echo "
server {
    listen 80;
    listen [::]:80;
    server_name $PPHOSTNAME;

    index index.php;

    location / {
        proxy_set_header X-Real-IP  \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$host;
        proxy_pass http://$PPIP:$PPPORT;
    }

    location ~* \.(?:ico|css|gif|jpe?g|png|ttf|woff)$ {
        access_log off;
        expires 30d;
        add_header Pragma public;
        add_header Cache-Control "public, mustrevalidate, proxy-revalidate";
        proxy_pass http://$PPIP:$PPPORT;
    }
}
" > $NGINX_SITES/$PPCONFIG
sudo ln -s $NGINX_SITES/$PPCONFIG $NGINX_EN/
sudo service nginx reload
echo "Done."
exit 0
