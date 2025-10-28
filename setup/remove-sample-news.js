const AWS = require('aws-sdk');

// Configure S3 client for MinIO
const s3Client = new AWS.S3({
  endpoint: process.env.MINIO_ENDPOINT,
  accessKeyId: 'minioadmin',
  secretAccessKey: process.env.MINIO_SECRET_KEY,
  s3ForcePathStyle: true,
  signatureVersion: 'v4',
  region: 'us-east-1',
});

async function listAllObjects() {
  try {
    console.log('Listing all objects in news-articles bucket...');
    
    const listParams = {
      Bucket: 'news-articles'
    };
    
    const objects = await s3Client.listObjectsV2(listParams).promise();
    
    if (objects.Contents && objects.Contents.length > 0) {
      console.log(`Found ${objects.Contents.length} objects:`);
      objects.Contents.forEach((obj, index) => {
        console.log(`  ${index + 1}. ${obj.Key} (Size: ${obj.Size} bytes, Modified: ${obj.LastModified})`);
      });
      return objects.Contents;
    } else {
      console.log('No objects found in the bucket.');
      return [];
    }
  } catch (error) {
    if (error.statusCode === 404) {
      console.log('Bucket news-articles does not exist.');
      return [];
    }
    throw error;
  }
}

async function deleteAllObjects(objects) {
  if (objects.length === 0) {
    console.log('No objects to delete.');
    return;
  }

  try {
    console.log(`\nDeleting ${objects.length} objects...`);
    
    // Prepare objects for deletion
    const deleteParams = {
      Bucket: 'news-articles',
      Delete: {
        Objects: objects.map(obj => ({ Key: obj.Key })),
        Quiet: false
      }
    };
    
    const result = await s3Client.deleteObjects(deleteParams).promise();
    
    if (result.Deleted && result.Deleted.length > 0) {
      console.log(`Successfully deleted ${result.Deleted.length} objects:`);
      result.Deleted.forEach((deleted, index) => {
        console.log(`  ${index + 1}. ${deleted.Key}`);
      });
    }
    
    if (result.Errors && result.Errors.length > 0) {
      console.log(`Errors deleting ${result.Errors.length} objects:`);
      result.Errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error.Key}: ${error.Message}`);
      });
    }
    
  } catch (error) {
    console.error('Error deleting objects:', error);
    throw error;
  }
}

async function cleanupBucket() {
  try {
    console.log('🧹 Starting cleanup of news-articles bucket in MinIO...\n');
    
    // List all objects first
    const objects = await listAllObjects();
    
    if (objects.length === 0) {
      console.log('✅ Bucket is already empty or does not exist.');
      return;
    }
    
    // Ask for confirmation (in a real scenario)
    console.log(`\n⚠️  About to delete ${objects.length} objects from the news-articles bucket.`);
    
    // Delete all objects
    await deleteAllObjects(objects);
    
    console.log('\n✅ Cleanup completed successfully!');
    
    // Verify cleanup
    console.log('\nVerifying cleanup...');
    const remainingObjects = await listAllObjects();
    
    if (remainingObjects.length === 0) {
      console.log('✅ Bucket is now empty.');
    } else {
      console.log(`⚠️  ${remainingObjects.length} objects still remain in the bucket.`);
    }
    
  } catch (error) {
    console.error('❌ Failed to cleanup bucket:', error);
    throw error;
  }
}

// Run the cleanup script
cleanupBucket()
  .then(() => {
    console.log('\n🎉 Sample news articles have been successfully removed from the data lake!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Failed to remove sample articles:', error);
    process.exit(1);
  });
