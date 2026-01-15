import boto3
import os
import pytest
from botocore.exceptions import ClientError

@pytest.fixture(scope="module")
def s3_client():
    """Fixture to create a boto3 S3 client."""
    try:
        s3 = boto3.client(
            "s3",
            endpoint_url="http://localhost:9000",
            aws_access_key_id="minioadmin",
            aws_secret_access_key="minioadmin123",
            region_name="us-east-1"
        )
        s3.list_buckets()
        return s3
    except Exception as e:
        pytest.fail(f"Failed to connect to MinIO: {e}")

def test_bucket_creation(s3_client):
    """Test creating a new bucket in MinIO."""
    bucket_name = "test-bucket-creation"
    try:
        s3_client.create_bucket(Bucket=bucket_name)
        response = s3_client.list_buckets()
        buckets = [bucket["Name"] for bucket in response["Buckets"]]
        assert bucket_name in buckets
    finally:
        s3_client.delete_bucket(Bucket=bucket_name)

def test_file_upload_and_download(s3_client):
    """Test uploading and downloading a file to/from MinIO."""
    bucket_name = "test-bucket-files"
    s3_client.create_bucket(Bucket=bucket_name)
    file_content = b"this is a test file"
    file_name = "test_file.txt"
    try:
        s3_client.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)
        response = s3_client.get_object(Bucket=bucket_name, Key=file_name)
        retrieved_content = response["Body"].read()
        assert retrieved_content == file_content
    finally:
        s3_client.delete_object(Bucket=bucket_name, Key=file_name)
        s3_client.delete_bucket(Bucket=bucket_name)

def test_file_deletion(s3_client):
    """Test deleting a file from MinIO."""
    bucket_name = "test-bucket-deletion"
    s3_client.create_bucket(Bucket=bucket_name)
    file_name = "test_file_to_delete.txt"
    s3_client.put_object(Bucket=bucket_name, Key=file_name, Body=b"delete me")

    s3_client.delete_object(Bucket=bucket_name, Key=file_name)

    with pytest.raises(ClientError) as e:
        s3_client.get_object(Bucket=bucket_name, Key=file_name)
    assert e.value.response["Error"]["Code"] == "NoSuchKey"

    s3_client.delete_bucket(Bucket=bucket_name)

if __name__ == "__main__":
    pytest.main()
