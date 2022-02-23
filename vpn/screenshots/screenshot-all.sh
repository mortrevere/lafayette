ls /tmp/lafayette-screenshots/screen || mkdir /tmp/lafayette-screenshots/screen
curl -s localhost:8000/client-list > /tmp/lafayette-client-list

for IP in $(</tmp/lafayette-client-list); do

echo "$IP"
sshpass -p tvstore scp -o StrictHostKeyChecking=no ./lafayette-screenshot-grabber.sh pi@"$IP":/tmp/lafayette-screenshot-grabber.sh
sshpass -p tvstore ssh -o StrictHostKeyChecking=no pi@"$IP" bash /tmp/lafayette-screenshot-grabber.sh
sshpass -p tvstore scp -o StrictHostKeyChecking=no pi@"$IP":/tmp/lafayette-screenshot-thumb.png /tmp/lafayette-screenshots/screen/"$IP".png
echo "done"

done
