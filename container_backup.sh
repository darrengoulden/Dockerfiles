#!/usr/bin/env bash
# Container backup script.
# This script will backup all the containers in the container folder to the backup folder.

# Debug
# set -x

# Parameters
backup_folder="/mnt/folder/backups/"
container_folder="/mnt/folder/containers/"
tmp_folder="/tmp/"
logfile="/tmp/config_backup_error.tmp"
email="email@domain.com"
subject="$(date "+Container backup %Y-%m-%d_%H-%M-%S")"
encryption_passphrase=$(cat /mnt/folder/secrets/backup/encryption_passwd)
# the following is appended to and should be blank
compressed_files=""
start=$(date +%s)

# Check the backup folder exists for each container, if not create it
for cf in $(cd $container_folder; ls -d *; cd - > /dev/null 2>&1); do
    if [ ! -d "${backup_folder}${cf}" ]; then
        mkdir -p "${backup_folder}${cf}"
    fi
done

# Backup each container
for d in $(cd $container_folder; ls -d *; cd - > /dev/null 2>&1); do
    if [ -d "${container_folder}${d}" ]; then
        #if [ "${d}" == "calibre" ]; then
        #    continue
        #fi
        tmp_file="$(date "+${d}_backup_%Y-%m-%d_%H-%M-%S.tar.gz.gpg")"
        tar czvpf - "${container_folder}${d}" | gpg --batch --passphrase $encryption_passphrase --symmetric --cipher-algo aes256 -o "${tmp_folder}${tmp_file}" > /dev/null 2>&1
        mv "${tmp_folder}${tmp_file}" "${backup_folder}${d}"
        # Change ownership and permissions
        chown root:apps "${backup_folder}${d}/${tmp_file}"
        chmod 700 "${backup_folder}${d}/${tmp_file}"
        # Get the size of the file
        size=$(stat -c%s "${backup_folder}${d}/${tmp_file}")
        size_mb=$(awk "BEGIN {printf \"%.2f\", ${size}/1024/1024}")
        # Add the file to the list of compressed files
        compressed_files+="${tmp_file} - ${size_mb}MB\n"
        # Remove files older than 2 months from the backup folder
        find "${backup_folder}${d}" -type f -mtime +60 -exec rm {} \; > /dev/null 2>&1
    fi
done

end=$(date +%s)
runtime=$((end - start))
# Create the email
(
    echo "To: ${email}"
    echo "Subject: ${subject}"
    echo "Content-Type: text/html"
    echo "MIME-Version: 1.0"
    echo -e "\r\n"
    echo "<pre style=\"font-size:14px\">"
    echo ""
    echo "Automatic backup of containers completed."
    echo ""
    echo "Backup files:"
    echo -e "${compressed_files}"
    echo ""
    echo "Backup took ${runtime} seconds."
    echo ""
    echo "</pre>"
) >> "${logfile}"
# Send email
python3 /mnt/folder/scripts/sendmail.py --subject "${subject}" --to_address ${email} --mail_body_html $logfile > /dev/null 2>&1
rm "${logfile}"
