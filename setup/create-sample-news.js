const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');
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

// Generate deterministic article ID based on URL and title
function generateArticleId(url, title = '') {
  const content = (url + title).trim();
  return crypto.createHash('md5').update(content).digest('hex');
}

// Sample news articles (IDs will be generated from URL and title)
const sampleArticleTemplates = [
  {
    title: 'Breakthrough in Quantum Computing Achieved',
    description: 'Scientists have made a significant breakthrough in quantum computing, demonstrating a new method for error correction that could accelerate the development of practical quantum computers.',
    content: 'In a groundbreaking study published in Nature, researchers from MIT and IBM have developed a novel approach to quantum error correction that reduces computational overhead by 40%. This advancement brings us closer to practical quantum computers that could revolutionize fields from cryptography to drug discovery. The team demonstrated their method on a 127-qubit quantum processor, showing unprecedented stability in quantum calculations.',
    url: 'https://example.com/quantum-breakthrough',
    published_date: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
    author: 'Dr. Sarah Chen',
    source: 'Tech News Daily',
    category: 'Technology',
    tags: ['quantum computing', 'science', 'breakthrough', 'IBM', 'MIT'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'api',
    image_url: 'https://example.com/quantum-computer.jpg'
  },
  {
    title: 'Global Climate Summit Reaches Historic Agreement',
    description: 'World leaders at the Climate Summit have reached a unprecedented agreement on carbon emission reductions, setting ambitious targets for the next decade.',
    content: 'After intense negotiations lasting three days, representatives from 195 countries have signed the most comprehensive climate agreement to date. The accord includes binding commitments to reduce global carbon emissions by 60% by 2035, with developed nations leading the charge. The agreement also establishes a $500 billion fund to help developing countries transition to renewable energy sources.',
    url: 'https://example.com/climate-agreement',
    published_date: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(), // 5 hours ago
    author: 'Maria Rodriguez',
    source: 'Global News Network',
    category: 'Environment',
    tags: ['climate', 'environment', 'politics', 'sustainability', 'renewable energy'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'AI Assistant Revolutionizes Healthcare Diagnosis',
    description: 'A new AI system has shown remarkable accuracy in diagnosing rare diseases, potentially saving thousands of lives through early detection.',
    content: 'The AI system, developed by a team at Stanford Medical School, has achieved a 94% accuracy rate in diagnosing rare genetic disorders from patient symptoms and medical history. The system has been trained on over 2 million medical cases and can identify patterns that human doctors might miss. Clinical trials are set to begin at major hospitals across the United States next month.',
    url: 'https://example.com/ai-healthcare',
    published_date: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(), // 8 hours ago
    author: 'Dr. James Thompson',
    source: 'Medical Today',
    category: 'Healthcare',
    tags: ['AI', 'healthcare', 'diagnosis', 'Stanford', 'medical technology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'api',
    image_url: 'https://example.com/ai-medical.jpg'
  },
  {
    title: 'SpaceX Launches Revolutionary Satellite Network',
    description: 'SpaceX has successfully launched the first batch of next-generation satellites designed to provide ultra-high-speed internet globally.',
    content: 'The Falcon Heavy rocket carried 60 advanced satellites into orbit, marking the beginning of SpaceXs ambitious plan to deploy 4,000 next-generation satellites. These new satellites promise internet speeds up to 10 times faster than current offerings and will provide coverage to remote areas previously without reliable internet access. The constellation is expected to be fully operational by 2027.',
    url: 'https://example.com/spacex-satellites',
    published_date: new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString(), // 12 hours ago
    author: 'Alex Johnson',
    source: 'Space Chronicle',
    category: 'Space',
    tags: ['SpaceX', 'satellites', 'internet', 'technology', 'Falcon Heavy'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'Electric Vehicle Sales Surge 300% Globally',
    description: 'Electric vehicle adoption has accelerated dramatically, with sales increasing 300% year-over-year as governments push for cleaner transportation.',
    content: 'According to the latest report from the International Energy Agency, electric vehicle sales have skyrocketed globally, driven by improved battery technology, government incentives, and growing environmental awareness. Tesla, BYD, and traditional automakers like Ford and GM have all reported record-breaking sales figures. Infrastructure development has also accelerated, with charging stations increasing by 250% in the past year.',
    url: 'https://example.com/ev-sales-surge',
    published_date: new Date(Date.now() - 18 * 60 * 60 * 1000).toISOString(), // 18 hours ago
    author: 'Emma Wilson',
    source: 'Auto Industry Weekly',
    category: 'Automotive',
    tags: ['electric vehicles', 'Tesla', 'environment', 'automotive', 'sales'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'api'
  },
  {
    title: 'New Archaeological Discovery Rewrites Ancient History',
    description: 'Archaeologists have uncovered a previously unknown civilization that challenges our understanding of ancient human development.',
    content: 'A team of archaeologists working in the Amazon rainforest has discovered the remains of a sophisticated civilization that existed 3,000 years ago. The site includes advanced irrigation systems, complex urban planning, and artifacts suggesting a highly developed society. This discovery challenges previous assumptions about pre-Columbian civilizations and their technological capabilities. The findings were published in the Journal of Archaeological Science.',
    url: 'https://example.com/archaeology-discovery',
    published_date: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // 1 day ago
    author: 'Dr. Michael Foster',
    source: 'Archaeology Today',
    category: 'Science',
    tags: ['archaeology', 'history', 'Amazon', 'civilization', 'discovery'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss',
    image_url: 'https://example.com/ancient-ruins.jpg'
  },
  {
    title: 'These plants build ant condos that keep warring species apart',
    description: 'The unique architecture of some ball-like plants high in trees in Fiji lets violent ants live peacefully and feed the plant with valuable droppings.',
    content: 'In the cloud forests of Fiji, a remarkable partnership exists between plants and ants that showcases nature\'s ingenuity. Scientists have discovered that certain epiphytic plants have evolved specialized structures that house multiple ant species in separate chambers, preventing territorial conflicts while benefiting from the nutrients the ants provide. This mutualistic relationship demonstrates sophisticated evolutionary adaptation.',
    url: 'https://www.sciencenews.org/article/plant-warring-ants-apart-mutualism',
    published_date: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    author: 'Susan Milius',
    source: 'sciencenews',
    category: 'biology',
    tags: ['plants', 'ants', 'mutualism', 'fiji', 'biology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss',
    image_url: 'https://example.com/plant-ant.jpg'
  },
  {
    title: 'Seven superclouds sit just beyond the solar system',
    description: 'The superclouds probably produce star-forming clouds of gas, since most nearby stellar nurseries are located within the giants.',
    content: 'Astronomers have identified seven massive structures of gas and dust, dubbed "superclouds," in the immediate neighborhood of our solar system. These enormous formations, each spanning hundreds of light-years, appear to be stellar nurseries where new stars are born. The discovery helps explain the distribution of young stars in our galactic vicinity and provides insights into how stellar formation occurs on large scales.',
    url: 'https://www.sciencenews.org/article/seven-superclouds-sun-solar-system-star',
    published_date: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
    author: 'McKenzie Prillaman',
    source: 'sciencenews',
    category: 'astronomy',
    tags: ['astronomy', 'space', 'stars', 'solar system', 'gas clouds'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'New Archaeological Discovery Rewrites Ancient History',
    description: 'Archaeologists have uncovered a previously unknown civilization that challenges our understanding of ancient human development.',
    content: 'A team of archaeologists working in the Amazon rainforest has discovered the remains of a sophisticated civilization that existed 3,000 years ago. The site includes advanced irrigation systems, complex urban planning, and artifacts suggesting a highly developed society. This discovery challenges previous assumptions about pre-Columbian civilizations and their technological capabilities. The findings were published in the Journal of Archaeological Science.',
    url: 'https://example.com/archaeology-discovery',
    published_date: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    author: 'Dr. Michael Foster',
    source: 'Archaeology Today',
    category: 'Science',
    tags: ['archaeology', 'history', 'Amazon', 'civilization', 'discovery'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss',
    image_url: 'https://example.com/ancient-ruins.jpg'
  },
  {
    title: 'These plants build ant condos that keep warring species apart',
    description: 'The unique architecture of some ball-like plants high in trees in Fiji lets violent ants live peacefully and feed the plant with valuable droppings.',
    content: 'In the cloud forests of Fiji, a remarkable partnership exists between plants and ants that showcases nature\'s ingenuity. Scientists have discovered that certain epiphytic plants have evolved specialized structures that house multiple ant species in separate chambers, preventing territorial conflicts while benefiting from the nutrients the ants provide. This mutualistic relationship demonstrates sophisticated evolutionary adaptation.',
    url: 'https://www.sciencenews.org/article/plant-warring-ants-apart-mutualism',
    published_date: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    author: 'Susan Milius',
    source: 'sciencenews',
    category: 'biology',
    tags: ['plants', 'ants', 'mutualism', 'fiji', 'biology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss',
    image_url: 'https://example.com/plant-ant.jpg'
  },
  {
    title: 'Seven superclouds sit just beyond the solar system',
    description: 'The superclouds probably produce star-forming clouds of gas, since most nearby stellar nurseries are located within the giants.',
    content: 'Astronomers have identified seven massive structures of gas and dust, dubbed "superclouds," in the immediate neighborhood of our solar system. These enormous formations, each spanning hundreds of light-years, appear to be stellar nurseries where new stars are born. The discovery helps explain the distribution of young stars in our galactic vicinity and provides insights into how stellar formation occurs on large scales.',
    url: 'https://www.sciencenews.org/article/seven-superclouds-sun-solar-system-star',
    published_date: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
    author: 'McKenzie Prillaman',
    source: 'sciencenews',
    category: 'astronomy',
    tags: ['astronomy', 'space', 'stars', 'solar system', 'gas clouds'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'AI is designing proteins that could help treat cancer',
    description: 'Artificial intelligence systems are now capable of designing novel protein structures that could lead to breakthrough cancer treatments.',
    content: 'Researchers have developed AI models that can design entirely new proteins with specific therapeutic functions. These artificially designed proteins show promise in targeting cancer cells more precisely than traditional treatments, potentially reducing side effects while improving efficacy. The breakthrough represents a major step forward in computational biology and personalized medicine.',
    url: 'https://www.sciencenews.org/article/generative-ai-protein-design-cancer',
    published_date: new Date(Date.now() - 9 * 60 * 60 * 1000).toISOString(),
    author: 'Science News Staff',
    source: 'sciencenews',
    category: 'artificial_intelligence',
    tags: ['AI', 'proteins', 'cancer', 'medicine', 'computational biology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'Revolutionary Gene Therapy Restores Vision in Blind Patients',
    description: 'Scientists have successfully restored partial vision to patients with inherited blindness using a breakthrough gene therapy approach that delivers corrective genes directly to retinal cells.',
    content: 'In a groundbreaking clinical trial, researchers have demonstrated that gene therapy can restore functional vision to patients with Leber congenital amaurosis, a rare genetic disorder that causes childhood blindness. The therapy involves injecting a modified virus carrying corrective genes directly into the eye, allowing damaged retinal cells to begin producing the proteins necessary for vision. Of the 18 patients treated, 16 showed measurable improvements in light sensitivity and navigation ability.',
    url: 'https://www.sciencedaily.com/releases/2025/07/250731001234.htm',
    published_date: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    author: 'ScienceDaily',
    source: 'sciencedaily_health_medicine',
    category: 'health',
    tags: ['gene therapy', 'vision', 'blindness', 'clinical trial', 'biotechnology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss',
    image_url: 'https://example.com/gene-therapy.jpg'
  },
  {
    title: 'Quantum Sensors Detect Dark Matter Candidates in Laboratory Setting',
    description: 'Physicists using ultra-sensitive quantum sensors have detected previously unobservable particles that could be dark matter, bringing us closer to solving one of cosmology\'s greatest mysteries.',
    content: 'A team of physicists at the University of California has developed quantum sensors so sensitive they can detect individual particle interactions that might represent dark matter. The sensors, operating at temperatures near absolute zero, have identified anomalous signals that match theoretical predictions for axions, hypothetical particles that could make up a significant portion of dark matter. This represents the first laboratory detection of potential dark matter candidates using quantum sensing technology.',
    url: 'https://www.sciencedaily.com/releases/2025/07/250731002345.htm',
    published_date: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
    author: 'ScienceDaily',
    source: 'sciencedaily_top_science',
    category: 'science',
    tags: ['quantum sensors', 'dark matter', 'physics', 'axions', 'cosmology'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'AI System Designs New Antibiotics That Overcome Drug Resistance',
    description: 'Artificial intelligence has successfully designed novel antibiotic compounds that can defeat drug-resistant bacteria, offering hope in the fight against superbugs.',
    content: 'Researchers at MIT have trained an AI system to design new antibiotic molecules that can overcome bacterial resistance mechanisms. The AI analyzed thousands of molecular structures and their effectiveness against various pathogens, then generated entirely new compounds with enhanced antimicrobial properties. Laboratory tests show these AI-designed antibiotics are effective against MRSA and other drug-resistant infections that cause thousands of deaths annually.',
    url: 'https://www.sciencedaily.com/releases/2025/07/250731003456.htm',
    published_date: new Date(Date.now() - 9 * 60 * 60 * 1000).toISOString(),
    author: 'ScienceDaily',
    source: 'sciencedaily_artificial_intelligence',
    category: 'artificial_intelligence',
    tags: ['artificial intelligence', 'antibiotics', 'drug resistance', 'bacteria', 'medicine'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'Ocean Plastic Pollution Creates Unprecedented Marine Heat Islands',
    description: 'Scientists have discovered that massive accumulations of plastic debris in the ocean are creating localized warming zones that disrupt marine ecosystems and weather patterns.',
    content: 'New research reveals that the Great Pacific Garbage Patch and other plastic accumulation zones are absorbing and retaining heat at rates 15-20% higher than surrounding waters. This creates "marine heat islands" that alter local ocean currents, affect marine life migration patterns, and potentially influence regional weather systems. The study used satellite thermal imaging and underwater temperature sensors to map these previously unknown warming zones across the world\'s oceans.',
    url: 'https://www.sciencedaily.com/releases/2025/07/250731004567.htm',
    published_date: new Date(Date.now() - 15 * 60 * 60 * 1000).toISOString(),
    author: 'ScienceDaily',
    source: 'sciencedaily_environment',
    category: 'environment',
    tags: ['ocean pollution', 'plastic waste', 'marine ecosystems', 'climate change', 'oceanography'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  },
  {
    title: 'Brain Organoids Reveal How Memories Form in Real-Time',
    description: 'Lab-grown brain tissue has provided unprecedented insights into memory formation, showing how neural networks reorganize themselves during learning processes.',
    content: 'Scientists at Harvard Medical School have created brain organoids—lab-grown neural tissue—that can form memories and demonstrate learning behaviors. Using advanced imaging techniques, researchers watched in real-time as neural connections strengthened and new pathways formed during memory consolidation. This breakthrough provides a new model for studying memory disorders like Alzheimer\'s disease and could lead to treatments that enhance memory formation or prevent memory loss.',
    url: 'https://www.sciencedaily.com/releases/2025/07/250731005678.htm',
    published_date: new Date(Date.now() - 21 * 60 * 60 * 1000).toISOString(),
    author: 'ScienceDaily',
    source: 'sciencedaily_health_medicine',
    category: 'health',
    tags: ['brain organoids', 'memory', 'neuroscience', 'learning', 'alzheimers'],
    ingestion_timestamp: new Date().toISOString(),
    source_type: 'rss'
  }
];

// Generate sample articles with deterministic IDs
const sampleArticles = sampleArticleTemplates.map(template => ({
  ...template,
  id: generateArticleId(template.url, template.title)
}));

async function createBucketIfNotExists() {
  try {
    await s3Client.headBucket({ Bucket: 'news-articles' }).promise();
    console.log('Bucket news-articles already exists');
  } catch (error) {
    if (error.statusCode === 404) {
      console.log('Creating bucket news-articles...');
      await s3Client.createBucket({ Bucket: 'news-articles' }).promise();
      console.log('Bucket created successfully');
    } else {
      throw error;
    }
  }
}

async function uploadSampleArticles() {
  try {
    console.log('Creating bucket if it doesn\'t exist...');
    await createBucketIfNotExists();

    // Create articles directory structure by date
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    
    const fileKey = `articles/${year}/${month}/${day}/sample-articles.jsonl`;
    
    // Convert articles to JSONL format (one JSON object per line)
    const jsonlContent = sampleArticles.map(article => JSON.stringify(article)).join('\n');
    
    console.log('Uploading sample articles to MinIO...');
    await s3Client.putObject({
      Bucket: 'news-articles',
      Key: fileKey,
      Body: jsonlContent,
      ContentType: 'application/jsonl'
    }).promise();
    
    console.log(`Successfully uploaded ${sampleArticles.length} sample articles to ${fileKey}`);
    console.log('Sample articles:');
    sampleArticles.forEach((article, index) => {
      console.log(`  ${index + 1}. ${article.title} (${article.category})`);
    });
    
  } catch (error) {
    console.error('Error uploading sample articles:', error);
    throw error;
  }
}

// Run the script
uploadSampleArticles()
  .then(() => {
    console.log('\n✅ Sample news articles have been successfully added to the data lake!');
    console.log(`You can now test the news feed at: ${process.env.FRONTEND_URL}/news`);
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Failed to upload sample articles:', error);
    process.exit(1);
  });
