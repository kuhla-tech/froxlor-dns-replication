#!/bin/bash

# ------------------------------
# Master/Slave Variablen
# ------------------------------

MASTER_IPV4="0.0.0.0"
MASTER_IPV6="::"
MASTER_NAME="examplehost"

# Zwei Slaves (nur IPv4 wird genutzt)
SLAVES_IPV4=("0.0.0.0" "0.0.0.0")

# Zone-Datei von Froxlor
ZONEFILE="/etc/bind/froxlor_bind.conf"

# Ziel-Datei auf den Slaves
SLAVE_TARGET="/etc/bind/$MASTER_NAME-slave-zones.conf"

TMP="/tmp/$MASTER_NAME-slave-zones.conf"
echo "" > $TMP

# ------------------------------
# Zonen aus Froxlor extrahieren
# ------------------------------

grep 'zone "' $ZONEFILE | while read -r line; do
    ZONE=$(echo "$line" | cut -d'"' -f2)

    echo "zone \"$ZONE\" {" >> $TMP
    echo "    type slave;" >> $TMP
    echo "    masters { $MASTER_IPV4; $MASTER_IPV6; };" >> $TMP
    echo "    file \"/var/cache/bind/$ZONE.db\";" >> $TMP
    echo "};" >> $TMP
done

# ------------------------------
# Datei an alle Slaves per IPv4 übertragen
# ------------------------------

for SLAVE in "${SLAVES_IPV4[@]}"; do
    echo "Sync zu Slave $SLAVE..."

    scp -4 $TMP root@$SLAVE:$SLAVE_TARGET

    # Include sicherstellen
    ssh -4 root@$SLAVE bash -s <<EOF
CONF="/etc/bind/named.conf.local"
INCLUDE="include \"$SLAVE_TARGET\";"

[ -f "\$CONF" ] || touch "\$CONF"

grep -qF "\$INCLUDE" "\$CONF"
if [ \$? -ne 0 ]; then
    echo "\$INCLUDE" >> "\$CONF"
fi
EOF

    # Reload
    ssh -4 root@$SLAVE "rndc reload"

    if [ $? -eq 0 ]; then
        echo "Sync zu $SLAVE erfolgreich!"
    else
        echo "Sync zu $SLAVE fehlgeschlagen."
    fi
done
