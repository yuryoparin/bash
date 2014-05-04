#! /bin/bash

# The approx. time to run this script is 145 ms.

# First we extract the private PEM key from the .p12 file:
# openssl pkcs12 -nocerts -passin 'notasecret' -in file.p12 -out ~/google/google.privatekey.pem 
KEY='~/google/google.privatekey.pem'

# The fields are ordered by their hash values.
# In Google Client for Java HashMap is used to stack all JSON fields, so String.hashCode() is used for ordering.
header='{"alg":"RS256","typ":"JWT"}'

aud='https://accounts.google.com/o/oauth2/token'
exp=$(date --date='+1 hour' +%s)
iat=$(date +%s)
iss='' # TODO: Put your Service Account's Email address
scope='https://www.googleapis.com/auth/youtube.readonly'

# The fields are ordered by their hash values.
# In Google Client for Java HashMap is used to stack all JSON fields, so String.hashCode() is used for ordering.
claim="{\"aud\":\"$aud\",\"exp\":$exp,\"iat\":$iat,\"iss\":\"$iss\",\"scope\":\"$scope\"}"

#echo "exp = $exp"

header_b64=$(echo -n "$header" | base64 -w 0 | sed 's/+/-/g;s/\//_/g;s/=//g') # base64url
claim_b64=$(echo -n "$claim" | base64 -w 0 | sed 's/+/-/g;s/\//_/g;s/=//g') # base64url
signature_b64=$(echo -n "$header_b64.$claim_b64" | openssl dgst -sha256 -sign $KEY | base64 -w 0 | sed 's/+/-/g;s/\//_/g;s/=//g')

jwt=$(echo -n "$header_b64.$claim_b64.$signature_b64")
#echo $jwt

result=$(curl -s -m 60 --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer --data-urlencode assertion=$jwt https://accounts.google.com/o/oauth2/token)
access_token=$(echo "$result" | grep -oP '"access_token" : "*\K([a-zA-Z0-9\.\-_])*')

#echo "access_token = $access_token" # valid for 3600 seconds

# The while-loop waits 60 seconds for Redis to start after reboot
cnt=0
PING=$(/usr/local/bin/redis-cli PING 2>&1) # stderr to stdout

while [ "$PING" != "PONG" ] && (($cnt < 6)); do
  sleep 10;
  let cnt=$cnt+1
  PING=$(/usr/local/bin/redis-cli PING 2>&1)
  echo "cnt = $cnt, PING = $PING"
done

log_date=$(date +'%Y/%m/%d %T')

if [[ $PING == 'PONG' ]]; then
  # Redis key: google-access-token
  redis_result=$(/usr/local/bin/redis-cli SET google-access-token "$access_token")
  echo "[$log_date] access_token = $access_token, exp = $exp, redis SET google-access-token [$redis_result], redis_connection_attempts = $cnt"
else
  echo "[$log_date] access_token = $access_token, exp = $exp, REDIS IS NOT UP: $PING"
fi
