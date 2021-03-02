import { BucketItem, BucketStream, Client, ItemBucketMetadata } from 'minio';

const minioClient = new Client({
    endPoint: '',
    port: 443,
    useSSL: true,
    accessKey: "",
    secretKey: "",
  });

const buckets = minioClient.listBuckets()
  .then(res => {
    res.forEach(bucket => {
      if (bucket.name == 'deeploy') {
        return;
      }
      let objectsStream: BucketStream<BucketItem> = minioClient.listObjectsV2(bucket.name, '', true);
      const objectsList = [];
      objectsStream.on('data', (obj: BucketItem) => {
        objectsList.push(obj.name);
      });
      objectsStream.on('error', e => {
        console.log(e);
      });
      objectsStream.on('end', () => {
        objectsList.forEach(itemName => {
          minioClient.getObject(bucket.name, itemName)
          .then(file => {
            minioClient.putObject('deeploy', bucket.name + '/' + itemName, file);
          })
          .catch();
        });
      });
    });
  })
  .catch(err => {

  });