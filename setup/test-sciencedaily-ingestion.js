const AWS = require('aws-sdk');
const https = require('https');

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

// ScienceDaily RSS feeds to test
const SCIENCEDAILY_FEEDS = [
  {
    name: 'sciencedaily_top_science',
    url: 'https://www.sciencedaily.com/rss/top/science.xml',
    category: 'science'
  },
  {
    name: 'sciencedaily_health_medicine',
    url: 'https://www.sciencedaily.com/rss/health_medicine.xml',
    category: 'health'
  },
  {
    name: 'sciencedaily_technology',
    url: 'https://www.sciencedaily.com/rss/top/technology.xml',
    category: 'technology'
  },
  {
    name: 'sciencedaily_artificial_intelligence',
    url: 'https://www.sciencedaily.com/rss/computers_math/artificial_intelligence.xml',
    category: 'artificial_intelligence'
  }
];

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
    if (index >= 5) return; // Limit to 5 articles per feed for testing
    
    const titleMatch = item.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/s) || item.match(/<title>(.*?)<\/title>/s);
    const linkMatch = item.match(/<link>(.*?)<\/link>/s);
    const descriptionMatch = item.match(/<description><!\[CDATA\[(.*?)\]\]><\/description>/s) || item.match(/<description>(.*?)<\/description>/s);
    const pubDateMatch = item.match(/<pubDate>(.*?)<\/pubDate>/s);
    
    if (titleMatch && linkMatch) {
      const article = {
        id: `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        title: titleMatch[1].trim(),
        description: descriptionMatch ? descriptionMatch[1].trim() : '',
        content: descriptionMatch ? descriptionMatch[1].trim() : '',
        url: linkMatch[1].trim(),
        published_date: pubDateMatch ? pubDateMatch[1].trim() : new Date().toISOString(),
        author: 'ScienceDaily',
        source: 'sciencedaily',
        category: 'science',
        tags: ['science', 'research'],
        ingestion_timestamp: new Date().toISOString(),
        source_type: 'rss'
      };
      articles.push(article);
    }
  });
  
  return articles;
}

async function testScienceDailyIngestion() {
  console.log('🧪 Testing ScienceDaily RSS feed ingestion...\n');
  
  try {
    let allArticles = [];
    
    // Test each RSS feed
    for (const feed of SCIENCEDAILY_FEEDS) {
      console.log(`📡 Fetching articles from ${feed.name}...`);
      
      try {
        const xmlContent = await fetchRSSFeed(feed.url);
        const articles = parseSimpleRSS(xmlContent);
        
        // Update category for each article
        articles.forEach(article => {
          article.category = feed.category;
          article.source = feed.name;
        });
        
        allArticles = allArticles.concat(articles);
        console.log(`   ✅ Fetched ${articles.length} articles from ${feed.name}`);
        
        // Display sample article
        if (articles.length > 0) {
          const sample = articles[0];
          console.log(`   📰 Sample: "${sample.title.substring(0, 60)}..."`);
        }
        
      } catch (error) {
        console.log(`   ❌ Error fetching ${feed.name}: ${error.message}`);
      }
    }
    
    if (allArticles.length === 0) {
      console.log('❌ No articles were fetched from any feed.');
      return;
    }
    
    console.log(`\n📊 Total articles fetched: ${allArticles.length}`);
    
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
    
    const fileKey = `articles/${year}/${month}/${day}/sciencedaily_test_${timestamp}.jsonl`;
    
    // Convert to JSONL format
    const jsonlContent = allArticles.map(article => JSON.stringify(article)).join('\n');
    
    console.log('💾 Storing articles in MinIO...');
    await s3Client.putObject({
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: jsonlContent,
      ContentType: 'application/jsonl'
    }).promise();
    
    console.log(`✅ Successfully stored ${allArticles.length} ScienceDaily articles to ${fileKey}`);
    
    // Store metadata
    const metadata = {
      test_run: true,
      total_articles: allArticles.length,
      sources: [...new Set(allArticles.map(a => a.source))],
      categories: [...new Set(allArticles.map(a => a.category))],
      ingestion_date: new Date().toISOString(),
      file_path: fileKey
    };
    
    const metadataKey = `metadata/${year}/${month}/${day}/sciencedaily_test_${timestamp}_metadata.json`;
    
    await s3Client.putObject({
      Bucket: BUCKET_NAME,
      Key: metadataKey,
      Body: JSON.stringify(metadata, null, 2),
      ContentType: 'application/json'
    }).promise();
    
    console.log(`📋 Metadata stored to ${metadataKey}`);
    
    // Display summary
    console.log('\n📈 Ingestion Summary:');
    console.log(`   Total Articles: ${allArticles.length}`);
    console.log(`   Categories: ${[...new Set(allArticles.map(a => a.category))].join(', ')}`);
    console.log(`   Sources: ${[...new Set(allArticles.map(a => a.source))].join(', ')}`);
    
    console.log('\n🎉 ScienceDaily test ingestion completed successfully!');
    console.log(`💡 You can now view these articles in your news feed at ${process.env.FRONTEND_URL}/news`);
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    throw error;
  }
}

// Run the test
testScienceDailyIngestion()
  .then(() => {
    console.log('\n✅ Test completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });
