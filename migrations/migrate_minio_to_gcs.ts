import { BucketItem, BucketStream, Client, ItemBucketMetadata } from 'minio';
import { v4 as uuidv4 } from 'uuid';
import { Storage } from '@google-cloud/storage';
import * as fs from 'fs';

const minioBucketName = 'deeploy-ute';
const gcsBucketName = 'deeploy-ute';

const minioClient = new Client({
    endPoint: '',
    port: 443,
    useSSL: true,
    accessKey: "",
    secretKey: "",
  });

const gcsClient = new Storage();

const buckets = minioClient.listBuckets()
  .then(res => {
    res.forEach(bucket => {
      if (bucket.name !== minioBucketName) {
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
        objectsList.forEach(async itemName => {
          let localFileName = uuidv4();
          minioClient.fGetObject(bucket.name, itemName, localFileName)
          .then(async file => {
            await gcsClient.bucket(gcsBucketName).upload(localFileName, {
              // Support for HTTP requests made with `Accept-Encoding: gzip`
              gzip: true,
              // By setting the option `destination`, you can change the name of the
              // object you are uploading to a bucket.
              destination: itemName,
              metadata: {
                // Enable long-lived HTTP caching headers
                // Use only if the contents of the file will never change
                // (If the contents will change, use cacheControl: 'no-cache')
                cacheControl: 'public, max-age=31536000',
              },
            });
            // TODO delete file
            await fs.unlink(localFileName, (err) => {
              if (err) {
                console.error(err)
                return
              }
            });
          })
          .catch();
        });
      });
    });
  })
  .catch(err => {

  });