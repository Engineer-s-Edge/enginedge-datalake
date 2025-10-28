const AWS = require('aws-sdk');
const https = require('https');
const crypto = require('crypto');

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

// Generate deterministic article ID based on URL and title
function generateArticleId(url, title = '') {
  const normalizedUrl = url
    .toLowerCase()
    .replace(/\/$/, '') // Remove trailing slash
    .replace(/^https?:\/\//, '') // Remove protocol
    .replace(/\/+/g, '/') // Normalize multiple slashes
    .trim();
  
  const normalizedTitle = (title || '')
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ') // Replace special chars with spaces
    .replace(/\s+/g, ' ') // Normalize multiple spaces
    .trim();
  
  const content = (normalizedUrl + normalizedTitle).trim();
  return crypto.createHash('md5').update(content).digest('hex');
}

async function fetchRSSFeed(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve(data);
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

function parseSimpleRSS(xmlContent) {
  const articles = [];
  
  // Simple regex-based parsing for testing (in production, use proper XML parser)
  const itemRegex = /<item>(.*?)<\/item>/gs;
  const items = xmlContent.match(itemRegex) || [];
  
  items.forEach((item, index) => {
    if (index >= 10) return; // Limit to 10 articles for testing
    
    const titleMatch = item.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/s) || item.match(/<title>(.*?)<\/title>/s);
    const linkMatch = item.match(/<link>(.*?)<\/link>/s);
    const descriptionMatch = item.match(/<description><!\[CDATA\[(.*?)\]\]><\/description>/s) || item.match(/<description>(.*?)<\/description>/s);
    const pubDateMatch = item.match(/<pubDate>(.*?)<\/pubDate>/s);
    const creatorMatch = item.match(/<dc:creator><!\[CDATA\[(.*?)\]\]><\/dc:creator>/s);
    const categoryMatch = item.match(/<category><!\[CDATA\[(.*?)\]\]><\/category>/s);
    const enclosureMatch = item.match(/<enclosure\s+url="([^"]+)"\s+[^>]*type="image\/[^"]*"/);
    
    if (titleMatch && linkMatch) {
      // Extract category and map it
      let category = 'science'; // default
      if (categoryMatch) {
        const categoryName = categoryMatch[1].toLowerCase();
        if (categoryName.includes('health') || categoryName.includes('medicine')) {
          category = 'health';
        } else if (categoryName.includes('artificial intelligence') || categoryName.includes('ai')) {
          category = 'artificial_intelligence';
        } else if (categoryName.includes('technology') || categoryName.includes('computer')) {
          category = 'technology';
        } else if (categoryName.includes('environment') || categoryName.includes('climate') || categoryName.includes('earth')) {
          category = 'environment';
        } else if (categoryName.includes('astronomy') || categoryName.includes('space')) {
          category = 'astronomy';
        } else if (categoryName.includes('physics') || categoryName.includes('quantum')) {
          category = 'physics';
        } else if (categoryName.includes('animals') || categoryName.includes('biology') || categoryName.includes('life')) {
          category = 'biology';
        }
      }

      const article = {
        id: generateArticleId(linkMatch[1].trim(), titleMatch[1].trim()),
        title: titleMatch[1].trim(),
        description: descriptionMatch ? descriptionMatch[1].replace(/<[^>]*>/g, '').trim() : '',
        content: descriptionMatch ? descriptionMatch[1].replace(/<[^>]*>/g, '').trim() : '',
        url: linkMatch[1].trim(),
        published_date: pubDateMatch ? pubDateMatch[1].trim() : new Date().toISOString(),
        author: creatorMatch ? creatorMatch[1].trim() : 'Science News',
        source: 'sciencenews',
        category: category,
        tags: ['science', 'research', category],
        ingestion_timestamp: new Date().toISOString(),
        source_type: 'rss',
        image_url: enclosureMatch ? enclosureMatch[1] : undefined
      };
      articles.push(article);
    }
  });
  
  return articles;
}

async function testScienceNewsIngestion() {
  console.log('🧪 Testing Science News RSS feed ingestion...\n');
  
  try {
    const feedUrl = 'https://www.sciencenews.org/feed/';
    
    console.log(`📡 Fetching articles from Science News...`);
    
    const xmlContent = await fetchRSSFeed(feedUrl);
    const articles = parseSimpleRSS(xmlContent);
    
    if (articles.length === 0) {
      console.log('❌ No articles were fetched from Science News feed.');
      return;
    }
    
    console.log(`✅ Fetched ${articles.length} articles from Science News`);
    
    // Display sample articles
    articles.slice(0, 3).forEach((article, index) => {
      console.log(`\n📰 Sample Article ${index + 1}:`);
      console.log(`   Title: "${article.title}"`);
      console.log(`   Category: ${article.category}`);
      console.log(`   Author: ${article.author}`);
      console.log(`   Published: ${new Date(article.published_date).toLocaleDateString()}`);
      console.log(`   URL: ${article.url}`);
      if (article.image_url) {
        console.log(`   Image: ${article.image_url}`);
      }
    });
    
    console.log(`\n📊 Total articles fetched: ${articles.length}`);
    
    // Check if bucket exists, create if not
    try {
      await s3Client.headBucket({ Bucket: BUCKET_NAME }).promise();
      console.log('✅ MinIO bucket exists');
    } catch (error) {
      if (error.statusCode === 404) {
        console.log('🪣 Creating MinIO bucket...');
        await s3Client.createBucket({ Bucket: BUCKET_NAME }).promise();
        console.log('✅ MinIO bucket created');
      } else {
        throw error;
      }
    }
    
    // Store articles in MinIO
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    const timestamp = today.toISOString().replace(/[:.]/g, '-').split('T')[0] + '_' + 
                     today.toTimeString().split(' ')[0].replace(/:/g, '');
    
    const fileKey = `articles/${year}/${month}/${day}/sciencenews_test_${timestamp}.jsonl`;
    
    // Convert to JSONL format
    const jsonlContent = articles.map(article => JSON.stringify(article)).join('\n');
    
    console.log('💾 Storing articles in MinIO...');
    await s3Client.putObject({
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: jsonlContent,
      ContentType: 'application/jsonl'
    }).promise();
    
    console.log(`✅ Successfully stored ${articles.length} Science News articles to ${fileKey}`);
    
    // Store metadata
    const metadata = {
      test_run: true,
      total_articles: articles.length,
      source: 'sciencenews',
      categories: [...new Set(articles.map(a => a.category))],
      ingestion_date: new Date().toISOString(),
      file_path: fileKey
    };
    
    const metadataKey = `metadata/${year}/${month}/${day}/sciencenews_test_${timestamp}_metadata.json`;
    
    await s3Client.putObject({
      Bucket: BUCKET_NAME,
      Key: metadataKey,
      Body: JSON.stringify(metadata, null, 2),
      ContentType: 'application/json'
    }).promise();
    
    console.log(`📋 Metadata stored to ${metadataKey}`);
    
    // Display summary
    console.log('\n📈 Ingestion Summary:');
    console.log(`   Total Articles: ${articles.length}`);
    console.log(`   Categories: ${[...new Set(articles.map(a => a.category))].join(', ')}`);
    console.log(`   Source: Science News`);
    console.log(`   Articles with Images: ${articles.filter(a => a.image_url).length}`);
    
    console.log('\n🎉 Science News test ingestion completed successfully!');
    console.log(`💡 You can now view these articles in your news feed at ${process.env.FRONTEND_URL}/news`);
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    throw error;
  }
}

// Run the test
testScienceNewsIngestion()
  .then(() => {
    console.log('\n✅ Test completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });
