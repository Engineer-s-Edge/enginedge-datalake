"""
News Articles Ingestion DAG

This DAG ingests news articles from various sources and stores them in the data lake.
It processes RSS feeds, web scraping, and API sources to collect news articles.
"""

from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import requests
import feedparser
import json
import boto3
from minio import Minio
import pandas as pd
from urllib.parse import urljoin, urlparse
import hashlib
import logging

# Default DAG arguments
default_args = {
    'owner': 'enginedge',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Initialize DAG
dag = DAG(
    'news_ingestion_pipeline',
    default_args=default_args,
    description='Ingest news articles from various sources',
    schedule_interval=timedelta(hours=2),  # Run every 2 hours
    catchup=False,
    tags=['news', 'ingestion', 'data-lake']
)

# MinIO configuration
MINIO_ENDPOINT = 'minio:9000'
MINIO_ACCESS_KEY = 'minioadmin'
MINIO_SECRET_KEY = os.getenv('MINIO_SECRET_KEY')
MINIO_BUCKET = 'news-articles'

# News sources configuration - Only ScienceDaily sources
DEFAULT_NEWS_SOURCES = {
    'rss_feeds': [
        # ScienceDaily RSS feeds
        {
            'name': 'sciencedaily_top_science',
            'url': 'https://www.sciencedaily.com/rss/top/science.xml',
            'category': 'science'
        },
        {
            'name': 'sciencedaily_health_medicine',
            'url': 'https://www.sciencedaily.com/rss/health_medicine.xml',
            'category': 'health'
        },
        {
            'name': 'sciencedaily_technology',
            'url': 'https://www.sciencedaily.com/rss/top/technology.xml',
            'category': 'technology'
        },
        {
            'name': 'sciencedaily_environment',
            'url': 'https://www.sciencedaily.com/rss/top/environment.xml',
            'category': 'environment'
        },
        {
            'name': 'sciencedaily_space_time',
            'url': 'https://www.sciencedaily.com/rss/space_time.xml',
            'category': 'space'
        },
        {
            'name': 'sciencedaily_artificial_intelligence',
            'url': 'https://www.sciencedaily.com/rss/computers_math/artificial_intelligence.xml',
            'category': 'artificial_intelligence'
        },
        {
            'name': 'sciencedaily_energy_technology',
            'url': 'https://www.sciencedaily.com/rss/matter_energy/energy_technology.xml',
            'category': 'energy'
        },
        {
            'name': 'sciencedaily_biology',
            'url': 'https://www.sciencedaily.com/rss/plants_animals/biology.xml',
            'category': 'biology'
        },
        {
            'name': 'sciencedaily_physics',
            'url': 'https://www.sciencedaily.com/rss/matter_energy/physics.xml',
            'category': 'physics'
        },
        {
            'name': 'sciencedaily_chemistry',
            'url': 'https://www.sciencedaily.com/rss/matter_energy/chemistry.xml',
            'category': 'chemistry'
        },
        {
            'name': 'sciencedaily_earth_climate',
            'url': 'https://www.sciencedaily.com/rss/earth_climate.xml',
            'category': 'earth_science'
        },
        {
            'name': 'sciencedaily_fossils_ruins',
            'url': 'https://www.sciencedaily.com/rss/fossils_ruins.xml',
            'category': 'archaeology'
        }
    ],
    'api_sources': []
}
NEWS_SOURCES = Variable.get("news_sources", default_var=DEFAULT_NEWS_SOURCES, deserialize_json=True)

def initialize_minio():
    """Initialize MinIO client and create bucket if not exists"""
    try:
        client = Minio(
            MINIO_ENDPOINT,
            access_key=MINIO_ACCESS_KEY,
            secret_key=MINIO_SECRET_KEY,
            secure=False
        )
        
        # Create bucket if it doesn't exist
        if not client.bucket_exists(MINIO_BUCKET):
            client.make_bucket(MINIO_BUCKET)
            logging.info(f"Created bucket: {MINIO_BUCKET}")
        
        return client
    except Exception as e:
        logging.error(f"Error initializing MinIO: {e}")
        raise

def generate_article_id(url, title):
    """Generate unique article ID based on URL and title"""
    content = f"{url}_{title}".encode('utf-8')
    return hashlib.md5(content).hexdigest()

def extract_rss_articles(**context):
    """Extract articles from RSS feeds"""
    articles = []
    
    for source in NEWS_SOURCES['rss_feeds']:
        try:
            logging.info(f"Processing RSS feed: {source['name']}")
            feed = feedparser.parse(source['url'])
            
            for entry in feed.entries:
                # Extract content - handle different formats
                content = ''
                if hasattr(entry, 'content') and entry.content:
                    if isinstance(entry.content, list) and len(entry.content) > 0:
                        content = entry.content[0].get('value', '')
                    else:
                        content = str(entry.content)
                elif hasattr(entry, 'summary'):
                    content = entry.summary
                
                # Parse published date
                published_date = ''
                if hasattr(entry, 'published'):
                    published_date = entry.published
                elif hasattr(entry, 'updated'):
                    published_date = entry.updated
                
                # Extract author information
                author = ''
                if hasattr(entry, 'author'):
                    author = entry.author
                elif hasattr(entry, 'authors') and entry.authors:
                    author = ', '.join([a.name for a in entry.authors if hasattr(a, 'name')])
                
                # Extract tags
                tags = []
                if hasattr(entry, 'tags') and entry.tags:
                    tags = [tag.term for tag in entry.tags if hasattr(tag, 'term')]
                
                # Get description, fallback to summary
                description = getattr(entry, 'description', '') or getattr(entry, 'summary', '')
                
                article = {
                    'id': generate_article_id(entry.link, entry.title),
                    'title': entry.title,
                    'description': description,
                    'content': content,
                    'url': entry.link,
                    'published_date': published_date,
                    'author': author,
                    'source': source['name'],
                    'category': source['category'],
                    'tags': tags,
                    'ingestion_timestamp': datetime.utcnow().isoformat(),
                    'source_type': 'rss',
                    'image_url': getattr(entry, 'image', {}).get('href', '') if hasattr(entry, 'image') else ''
                }
                articles.append(article)
                
        except Exception as e:
            logging.error(f"Error processing RSS feed {source['name']}: {e}")
            continue
    
    logging.info(f"Extracted {len(articles)} articles from RSS feeds")
    return articles

def extract_api_articles(**context):
    """Extract articles from API sources"""
    articles = []
    
    for source in NEWS_SOURCES['api_sources']:
        try:
            logging.info(f"Processing API source: {source['name']}")
            
            # Get API key from environment (you'd set this in Airflow Variables)
            import os
            api_key = os.getenv(source.get('api_key_env', ''))
            
            if not api_key:
                logging.warning(f"No API key found for {source['name']}")
                continue
            
            # Make API request
            params = source['params'].copy()
            params['apiKey'] = api_key
            
            response = requests.get(source['endpoint'], params=params)
            response.raise_for_status()
            
            data = response.json()
            
            for article_data in data.get('articles', []):
                article = {
                    'id': generate_article_id(article_data['url'], article_data['title']),
                    'title': article_data['title'],
                    'description': article_data.get('description', ''),
                    'content': article_data.get('content', ''),
                    'url': article_data['url'],
                    'published_date': article_data.get('publishedAt', ''),
                    'author': article_data.get('author', ''),
                    'source': article_data.get('source', {}).get('name', source['name']),
                    'category': params.get('category', 'general'),
                    'tags': [],
                    'ingestion_timestamp': datetime.utcnow().isoformat(),
                    'source_type': 'api',
                    'image_url': article_data.get('urlToImage', '')
                }
                articles.append(article)
                
        except Exception as e:
            logging.error(f"Error processing API source {source['name']}: {e}")
            continue
    
    logging.info(f"Extracted {len(articles)} articles from API sources")
    return articles

def store_articles_to_datalake(**context):
    """Store articles to MinIO data lake"""
    # Get articles from previous tasks
    rss_articles = context['task_instance'].xcom_pull(task_ids='extract_rss_articles')
    api_articles = context['task_instance'].xcom_pull(task_ids='extract_api_articles')
    
    all_articles = (rss_articles or []) + (api_articles or [])
    
    if not all_articles:
        logging.info("No articles to store")
        return
    
    # Initialize MinIO client
    minio_client = initialize_minio()
    
    # Create DataFrame for easier processing
    df = pd.DataFrame(all_articles)
    
    # Generate partition path based on date
    partition_date = datetime.utcnow().strftime('%Y/%m/%d')
    batch_timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    
    # Store as JSON Lines format
    json_content = df.to_json(orient='records', lines=True)
    
    object_name = f"articles/{partition_date}/news_batch_{batch_timestamp}.jsonl"
    
    try:
        # Upload to MinIO
        from io import BytesIO
        json_bytes = json_content.encode('utf-8')
        
        minio_client.put_object(
            MINIO_BUCKET,
            object_name,
            BytesIO(json_bytes),
            length=len(json_bytes),
            content_type='application/x-ndjson'
        )
        
        logging.info(f"Stored {len(all_articles)} articles to {object_name}")
        
        # Also store metadata
        metadata = {
            'batch_id': batch_timestamp,
            'total_articles': len(all_articles),
            'sources': list(df['source'].unique()),
            'categories': list(df['category'].unique()),
            'ingestion_date': datetime.utcnow().isoformat(),
            'object_path': object_name
        }
        
        metadata_object = f"metadata/{partition_date}/batch_{batch_timestamp}_metadata.json"
        metadata_json = json.dumps(metadata, indent=2)
        
        minio_client.put_object(
            MINIO_BUCKET,
            metadata_object,
            BytesIO(metadata_json.encode('utf-8')),
            length=len(metadata_json.encode('utf-8')),
            content_type='application/json'
        )
        
        return {
            'articles_stored': len(all_articles),
            'object_path': object_name,
            'metadata_path': metadata_object
        }
        
    except Exception as e:
        logging.error(f"Error storing articles to MinIO: {e}")
        raise

def update_search_index(**context):
    """Update search index for articles (optional)"""
    storage_result = context['task_instance'].xcom_pull(task_ids='store_articles')
    
    if not storage_result:
        logging.info("No storage result to index")
        return
    
    logging.info(f"Would update search index for {storage_result['articles_stored']} articles")
    # Here you could add integration with Elasticsearch, Apache Solr, or your vector store
    return True

# Define tasks
extract_rss_task = PythonOperator(
    task_id='extract_rss_articles',
    python_callable=extract_rss_articles,
    dag=dag
)

extract_api_task = PythonOperator(
    task_id='extract_api_articles',
    python_callable=extract_api_articles,
    dag=dag
)

store_articles_task = PythonOperator(
    task_id='store_articles',
    python_callable=store_articles_to_datalake,
    dag=dag
)

update_index_task = PythonOperator(
    task_id='update_search_index',
    python_callable=update_search_index,
    dag=dag
)

# Define task dependencies
[extract_rss_task, extract_api_task] >> store_articles_task >> update_index_task
