#!/bin/sh

# Backup script for Paperless-ngx
# The backup folder is syncronized with a cloud service (e.g. Dropbox, Google Drive, etc.)
# Parameters
paperless_export="/mnt/folder/paperless/export" # host folder
container_export="/usr/src/paperless/export" # container folder
backup_folder="/mnt/folder/backups/paperless-ngx"
logfile="/tmp/config_backup_error.tmp"
filename="$(date "+paperless_backup_%Y-%m-%d_%H-%M-%S.tar.gz")"

email="email@domain.com"
subject="$(date "+Paperless-ngx export %Y-%m-%d_%H-%M-%S")"

container_name="paper-webserver"
db_pass=$(cat /mnt/folder/secrets/paperless/paper_dbpass)

encryption_passphrase=$(cat /mnt/folder/secrets/scripts/encryption_passwd)

# Remove files older than 2 months from the backup folder
find "${backup_folder}" -type f -mtime +60 -exec rm {} \;  > /dev/null 2>&1

# Run the backup
# https://docs.paperless-ngx.com/administration/#exporter
docker exec -it $container_name document_exporter $container_export --passphrase $db_pass --no-progress-bar > /dev/null 2>&1
if [ $? -eq 0 ]; then
    cd $paperless_export
    tar czvpf - . | gpg --batch --passphrase $encryption_passphrase --symmetric --cipher-algo aes256 -o "${filename}" > /dev/null 2>&1
    mv "${filename}" "${backup_folder}"
    chown root:apps "${backup_folder}/${filename}"
    chmod 700 "${backup_folder}/${filename}"
    rm -f "${paperless_export}/*"
    size=$(stat -c%s "${backup_folder}/${filename}")
    size_mb=$(awk "BEGIN {printf \"%.2f\", ${size}/1024/1024}")
    (
        echo "To: ${email}"
        echo "Subject: ${subject}"
        echo "Content-Type: text/html"
        echo "MIME-Version: 1.0"
        echo -e "\r\n"
        echo "<pre style=\"font-size:14px\">"
        echo ""
        echo "Automatic backup of Paperless-ngx completed."
        echo ""
        echo "Backup file: ${filename}"
        echo "Backup size: ${size_mb}MB"
        echo ""
        echo "</pre>"
    ) >> "${logfile}"
    # Send email
    python3 /mnt/nas/folder/scripts/sendmail.py --subject "${subject}" --to_address ${email} --mail_body_html $logfile > /dev/null 2>&1
    #mail -s "${subject}" "${email}"
    rm "${logfile}"
else
    (
        echo "To: ${email}"
        echo "Subject: ${subject}"
        echo "Content-Type: text/html"
        echo "MIME-Version: 1.0"
        echo -e "\r\n"
        echo "<pre style=\"font-size:14px\">"
        echo ""
        echo "Automatic backup of Paperless-ngx failed."
        echo ""
        echo "The backup command returned an error."
        echo ""
        echo "You should correct this problem as soon as possible."
        echo ""
        echo "</pre>"
    ) >> "${logfile}"
    #sendmail -t < "${logfile}"
    # Send email
    python3 /mnt/nas/folder/scripts/sendmail.py --subject "${subject}" --to_address ${email} --mail_body_html $logfile > /dev/null 2>&1
    rm "${logfile}"
fi
