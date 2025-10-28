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

function parseSimpleRDF(xmlContent) {
  const articles = [];
  
  // Simple regex-based parsing for RDF format (in production, use proper XML parser)
  const itemRegex = /<item[^>]*>(.*?)<\/item>/gs;
  const items = xmlContent.match(itemRegex) || [];
  
  items.forEach((item, index) => {
    if (index >= 10) return; // Limit to 10 articles for testing
    
    const titleMatch = item.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/s) || item.match(/<title>(.*?)<\/title>/s);
    const linkMatch = item.match(/<link>(.*?)<\/link>/s);
    const descriptionMatch = item.match(/<description><!\[CDATA\[(.*?)\]\]><\/description>/s) || item.match(/<description>(.*?)<\/description>/s);
    const dateMatch = item.match(/<dc:date>(.*?)<\/dc:date>/s);
    const creatorMatch = item.match(/<dc:creator>(.*?)<\/dc:creator>/s);
    const enclosureMatch = item.match(/<enc:enclosure\s+rdf:resource="([^"]+)"\s+[^>]*enc:type="image\/[^"]*"/);
    
    if (titleMatch && linkMatch) {
      // Extract category based on keywords in title and description
      let category = 'science'; // default
      const content = (titleMatch[1] + ' ' + (descriptionMatch ? descriptionMatch[1] : '')).toLowerCase();
      
      if (content.includes('health') || content.includes('medicine') || content.includes('medical')) {
        category = 'health';
      } else if (content.includes('artificial intelligence') || content.includes('ai') || content.includes('machine learning')) {
        category = 'artificial_intelligence';
      } else if (content.includes('technology') || content.includes('computer') || content.includes('engineering')) {
        category = 'technology';
      } else if (content.includes('environment') || content.includes('climate') || content.includes('earth') || content.includes('ecology')) {
        category = 'environment';
      } else if (content.includes('astronomy') || content.includes('space') || content.includes('planet') || content.includes('galaxy')) {
        category = 'astronomy';
      } else if (content.includes('physics') || content.includes('quantum') || content.includes('particle')) {
        category = 'physics';
      } else if (content.includes('biology') || content.includes('genetics') || content.includes('evolution') || content.includes('animal') || content.includes('plant')) {
        category = 'biology';
      } else if (content.includes('chemistry') || content.includes('chemical') || content.includes('molecular')) {
        category = 'chemistry';
      }

      const article = {
        id: generateArticleId(linkMatch[1].trim(), titleMatch[1].trim()),
        title: titleMatch[1].trim(),
        description: descriptionMatch ? descriptionMatch[1].replace(/<[^>]*>/g, '').trim() : '',
        content: descriptionMatch ? descriptionMatch[1].replace(/<[^>]*>/g, '').trim() : '',
        url: linkMatch[1].trim(),
        published_date: dateMatch ? new Date(dateMatch[1].trim()).toISOString() : new Date().toISOString(),
        author: creatorMatch ? creatorMatch[1].trim() : 'Science Magazine',
        source: 'science_org',
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

async function testScienceOrgIngestion() {
  console.log('🧪 Testing Science.org RSS feed ingestion...\n');
  
  try {
    const feedUrl = 'https://www.science.org/rss/news_current.xml';
    
    console.log(`📡 Fetching articles from Science.org...`);
    
    const xmlContent = await fetchRSSFeed(feedUrl);
    const articles = parseSimpleRDF(xmlContent);
    
    if (articles.length === 0) {
      console.log('❌ No articles were fetched from Science.org feed.');
      return;
    }
    
    console.log(`✅ Fetched ${articles.length} articles from Science.org`);
    
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
      if (error.code === 'NotFound') {
        console.log('📦 Creating MinIO bucket...');
        await s3Client.createBucket({ Bucket: BUCKET_NAME }).promise();
        console.log('✅ MinIO bucket created');
      } else {
        throw error;
      }
    }
    
    // Store articles in MinIO
    console.log('\n💾 Storing articles in MinIO...');
    
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    const timestamp = today.toISOString().replace(/[:.]/g, '-').split('T')[0] + '_' + 
                     today.toTimeString().split(' ')[0].replace(/:/g, '');
    
    const fileKey = `articles/${year}/${month}/${day}/science_org_test_${timestamp}.jsonl`;
    
    // Convert to JSONL format
    const jsonlContent = articles.map(article => JSON.stringify(article)).join('\n');
    
    // Store in MinIO
    await s3Client.putObject({
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: jsonlContent,
      ContentType: 'application/jsonl'
    }).promise();
    
    console.log(`✅ Stored ${articles.length} articles to MinIO at: ${fileKey}`);
    
    // Verify storage
    console.log('\n🔍 Verifying stored data...');
    const storedObject = await s3Client.getObject({
      Bucket: BUCKET_NAME,
      Key: fileKey
    }).promise();
    
    const storedContent = storedObject.Body.toString();
    const storedArticles = storedContent.split('\n').filter(line => line.trim()).map(line => JSON.parse(line));
    
    console.log(`✅ Verified: ${storedArticles.length} articles stored successfully`);
    
    // Show statistics
    const categoryStats = storedArticles.reduce((acc, article) => {
      acc[article.category] = (acc[article.category] || 0) + 1;
      return acc;
    }, {});
    
    console.log('\n📈 Category distribution:');
    Object.entries(categoryStats).forEach(([category, count]) => {
      console.log(`   ${category}: ${count} articles`);
    });
    
    console.log('\n🎉 Science.org RSS feed ingestion test completed successfully!');
    
  } catch (error) {
    console.error('❌ Error during Science.org ingestion test:', error.message);
    console.error('Stack trace:', error.stack);
  }
}

// Run the test
testScienceOrgIngestion().catch(console.error);
