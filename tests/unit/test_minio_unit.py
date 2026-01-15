import boto3
import pytest
from moto import mock_aws

@pytest.fixture(scope="function")
def s3_client():
    """Fixture to create a mocked boto3 S3 client using moto."""
    with mock_aws():
        s3 = boto3.client(
            "s3",
            region_name="us-east-1"
        )
        yield s3

@pytest.mark.unit
def test_bucket_creation(s3_client):
    """Unit Test creating a new bucket (Mocked)."""
    bucket_name = "test-bucket-creation"
    
    s3_client.create_bucket(Bucket=bucket_name)
    
    response = s3_client.list_buckets()
    buckets = [bucket["Name"] for bucket in response["Buckets"]]
    assert bucket_name in buckets

@pytest.mark.unit
def test_file_upload_and_download(s3_client):
    """Unit Test uploading and downloading a file (Mocked)."""
    bucket_name = "test-bucket-files"
    s3_client.create_bucket(Bucket=bucket_name)
    
    file_content = b"this is a test file"
    file_name = "test_file.txt"
    
    s3_client.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)
    
    response = s3_client.get_object(Bucket=bucket_name, Key=file_name)
    retrieved_content = response["Body"].read()
    assert retrieved_content == file_content
