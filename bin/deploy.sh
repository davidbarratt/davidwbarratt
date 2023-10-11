###########################################
echo "Update Deploy Job"
az containerapp job update -g davidwbarratt -n davidwbarratt-deploy --image $1 -o tsv --query 'name';

STATUS="";
while  [ "$STATUS" != "Succeeded" ]
do
  sleep 1;
  STATUS="$(az containerapp job show -g davidwbarratt -n davidwbarratt-deploy -o tsv --query 'properties.provisioningState')";
  echo $STATUS;
  if [ "$STATUS" = "Failed" ]
  then
    exit 1
  fi
done

###########################################
echo "Update Container App"
az containerapp update -g davidwbarratt -n davidwbarratt --image $1 -o tsv --query 'name';

STATUS="";
while  [ "$STATUS" != "Succeeded" ]
do
  sleep 1;
  STATUS="$(az containerapp show -g davidwbarratt -n davidwbarratt -o tsv --query 'properties.provisioningState')";
  echo $STATUS;
  if [ "$STATUS" = "Failed" ]
  then
    exit 1
  fi
done

###########################################
echo "Run Deployment Job"

NAME=$(az containerapp job start -g davidwbarratt -n davidwbarratt-deploy -o tsv --query 'name')
echo $NAME;

STATUS="";
while  [ "$STATUS" != "Succeeded" ]
do
  sleep 1;
  STATUS="$(az containerapp job execution show -g davidwbarratt -n davidwbarratt-deploy --job-execution-name "$NAME" -o tsv --query 'properties.status')";
  echo $STATUS;
  if [ "$STATUS" = "Failed" ]
  then
    exit 1
  fi
done
