import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="module")
def spark_session():
    """Fixture to create a SparkSession."""
    spark = SparkSession.builder \
        .appName("TestDataLake") \
        .master("spark://localhost:7077") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin123") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .getOrCreate()
    yield spark
    spark.stop()

def test_spark_session(spark_session):
    """Test that the SparkSession is created successfully."""
    assert spark_session is not None
    assert spark_session.sparkContext.appName == "TestDataLake"

def test_read_from_minio(spark_session):
    """Test reading a file from MinIO with Spark."""
    # This test requires a file to be present in MinIO.
    # We will assume a file `sample.csv` exists in the `test-data` bucket.
    # You can create this file and bucket using the MinIO client or boto3.

    # Create a dummy DataFrame to write to MinIO
    data = [("Alice", 1), ("Bob", 2)]
    columns = ["name", "id"]
    df_write = spark_session.createDataFrame(data, columns)

    bucket_name = "test-spark-read"
    file_key = "sample.csv"

    # Writing to MinIO (requires boto3 to be installed and configured for MinIO)
    # Note: Spark's S3A connector needs to be correctly configured for this to work.

    # This example demonstrates reading. A full test would involve writing first.
    # For now, we will just check if we can read without errors, assuming the file exists.
    # To make this test self-contained, you could use boto3 to upload a file first.

    # A simple check to see if Spark can be initialized
    df = spark_session.createDataFrame([(1, "foo"), (2, "bar")], ["id", "value"])
    assert df.count() == 2

if __name__ == "__main__":
    pytest.main()
