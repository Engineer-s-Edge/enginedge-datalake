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

const BUCKET_NAME = 'news-articles';

async function checkBucketExists() {
  try {
    await s3Client.headBucket({ Bucket: BUCKET_NAME }).promise();
    return true;
  } catch (error) {
    if (error.statusCode === 404) {
      return false;
    }
    throw error;
  }
}

async function listAllObjects(prefix = '') {
  try {
    const listParams = {
      Bucket: BUCKET_NAME,
      Prefix: prefix
    };
    
    let allObjects = [];
    let isTruncated = true;
    let continuationToken = null;
    
    while (isTruncated) {
      if (continuationToken) {
        listParams.ContinuationToken = continuationToken;
      }
      
      const response = await s3Client.listObjectsV2(listParams).promise();
      
      if (response.Contents) {
        allObjects = allObjects.concat(response.Contents);
      }
      
      isTruncated = response.IsTruncated;
      continuationToken = response.NextContinuationToken;
    }
    
    return allObjects;
  } catch (error) {
    console.error('Error listing objects:', error);
    throw error;
  }
}

async function deleteObjects(objects) {
  if (objects.length === 0) {
    return { deleted: [], errors: [] };
  }

  try {
    // S3 deleteObjects can handle up to 1000 objects at once
    const batchSize = 1000;
    let allDeleted = [];
    let allErrors = [];
    
    for (let i = 0; i < objects.length; i += batchSize) {
      const batch = objects.slice(i, i + batchSize);
      
      const deleteParams = {
        Bucket: BUCKET_NAME,
        Delete: {
          Objects: batch.map(obj => ({ Key: obj.Key })),
          Quiet: false
        }
      };
      
      const result = await s3Client.deleteObjects(deleteParams).promise();
      
      if (result.Deleted) {
        allDeleted = allDeleted.concat(result.Deleted);
      }
      
      if (result.Errors) {
        allErrors = allErrors.concat(result.Errors);
      }
    }
    
    return { deleted: allDeleted, errors: allErrors };
  } catch (error) {
    console.error('Error deleting objects:', error);
    throw error;
  }
}

async function cleanupNewsArticles(options = {}) {
  const { 
    prefix = '', 
    dryRun = false, 
    verbose = true 
  } = options;
  
  try {
    console.log('🧹 Starting MinIO news articles cleanup...\n');
    
    // Check if bucket exists
    const bucketExists = await checkBucketExists();
    if (!bucketExists) {
      console.log(`❌ Bucket '${BUCKET_NAME}' does not exist.`);
      return;
    }
    
    // List all objects
    console.log(`📋 Listing objects${prefix ? ` with prefix '${prefix}'` : ''}...`);
    const objects = await listAllObjects(prefix);
    
    if (objects.length === 0) {
      console.log('✅ No objects found to delete.');
      return;
    }
    
    console.log(`📦 Found ${objects.length} objects:`);
    
    if (verbose) {
      objects.forEach((obj, index) => {
        const sizeKB = (obj.Size / 1024).toFixed(2);
        console.log(`  ${index + 1}. ${obj.Key} (${sizeKB} KB, ${obj.LastModified.toLocaleDateString()})`);
      });
    }
    
    if (dryRun) {
      console.log('\n🔍 DRY RUN: Would delete the above objects (no actual deletion performed)');
      return;
    }
    
    console.log(`\n🗑️  Deleting ${objects.length} objects...`);
    
    const result = await deleteObjects(objects);
    
    if (result.deleted.length > 0) {
      console.log(`✅ Successfully deleted ${result.deleted.length} objects`);
      if (verbose && result.deleted.length <= 20) {
        result.deleted.forEach((deleted, index) => {
          console.log(`  ${index + 1}. ${deleted.Key}`);
        });
      }
    }
    
    if (result.errors.length > 0) {
      console.log(`❌ Failed to delete ${result.errors.length} objects:`);
      result.errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error.Key}: ${error.Message}`);
      });
    }
    
    // Verify cleanup
    console.log('\n🔍 Verifying cleanup...');
    const remainingObjects = await listAllObjects(prefix);
    
    if (remainingObjects.length === 0) {
      console.log('✅ All objects successfully removed!');
    } else {
      console.log(`⚠️  ${remainingObjects.length} objects still remain.`);
    }
    
  } catch (error) {
    console.error('❌ Cleanup failed:', error.message);
    throw error;
  }
}

// Command line argument parsing
const args = process.argv.slice(2);
const options = {};

args.forEach(arg => {
  if (arg === '--dry-run') {
    options.dryRun = true;
  } else if (arg === '--quiet') {
    options.verbose = false;
  } else if (arg.startsWith('--prefix=')) {
    options.prefix = arg.split('=')[1];
  }
});

// Show usage if help is requested
if (args.includes('--help') || args.includes('-h')) {
  console.log(`
Usage: node cleanup-news-articles.js [options]

Options:
  --dry-run          Show what would be deleted without actually deleting
  --quiet           Reduce verbose output
  --prefix=PREFIX   Only delete objects with the specified prefix
  --help, -h        Show this help message

Examples:
  node cleanup-news-articles.js                    # Delete all articles
  node cleanup-news-articles.js --dry-run          # Preview what would be deleted
  node cleanup-news-articles.js --prefix=articles/2025/07/  # Delete articles from July 2025
`);
  process.exit(0);
}

// Run the cleanup
cleanupNewsArticles(options)
  .then(() => {
    console.log('\n🎉 Cleanup operation completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Cleanup operation failed:', error);
    process.exit(1);
  });
