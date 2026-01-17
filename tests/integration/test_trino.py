import pytest
from trino.dbapi import connect
from trino.auth import BasicAuthentication

@pytest.fixture(scope="module")
def trino_conn():
    """Fixture to connect to the Trino database."""
    try:
        conn = connect(
            host="localhost",
            port=8090,
            user="admin",
            auth=BasicAuthentication("admin", "admin123"),
            catalog="hive",
            schema="default"
        )
        yield conn
        conn.close()
    except Exception as e:
        pytest.fail(f"Failed to connect to Trino: {e}")

def test_trino_connection(trino_conn):
    """Test that the connection to Trino is successful."""
    assert trino_conn is not None

def test_trino_query(trino_conn):
    """Test running a simple query in Trino."""
    cur = trino_conn.cursor()
    cur.execute("SELECT 1")
    result = cur.fetchone()
    assert result == (1,)
    cur.close()

if __name__ == "__main__":
    pytest.main()
