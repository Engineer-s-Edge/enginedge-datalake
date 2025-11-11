import psycopg2
import pytest

@pytest.fixture(scope="module")
def postgres_conn():
    """Fixture to connect to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host="localhost",
            port="5432",
            user="airflow",
            password="airflow",
            dbname="airflow"
        )
        yield conn
        conn.close()
    except psycopg2.OperationalError as e:
        pytest.fail(f"Failed to connect to PostgreSQL: {e}")

def test_connection(postgres_conn):
    """Test that the connection to PostgreSQL is successful."""
    assert postgres_conn is not None

def test_create_table(postgres_conn):
    """Test creating a table in PostgreSQL."""
    cur = postgres_conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, name VARCHAR);")
    postgres_conn.commit()
    cur.execute("SELECT to_regclass('public.test_table');")
    result = cur.fetchone()[0]
    assert result == 'test_table'
    cur.execute("DROP TABLE test_table;")
    postgres_conn.commit()
    cur.close()

def test_insert_and_select(postgres_conn):
    """Test inserting and selecting data from a table."""
    cur = postgres_conn.cursor()
    cur.execute("CREATE TABLE test_insert (id INT, name VARCHAR);")
    cur.execute("INSERT INTO test_insert (id, name) VALUES (%s, %s);", (1, "test_user"))
    postgres_conn.commit()

    cur.execute("SELECT id, name FROM test_insert WHERE id = 1;")
    row = cur.fetchone()
    assert row == (1, "test_user")

    cur.execute("DROP TABLE test_insert;")
    postgres_conn.commit()
    cur.close()

if __name__ == "__main__":
    pytest.main()
