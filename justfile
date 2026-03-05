default:
    @just --list

# Build the custom Airflow image
build:
    docker compose build

# Start the stack (build if needed)
up:
    docker compose up --build -d

# Stop the stack
down:
    docker compose down

# Show logs (follow)
logs:
    docker compose logs -f

# Run tests inside the scheduler container
test:
    docker compose exec airflow-scheduler pytest

# Run tests with coverage report
cov:
    docker compose exec airflow-scheduler pytest --cov=dags --cov-report=term-missing

# Format code with black
fmt:
    docker compose exec airflow-scheduler black dags/ tests/

# Check formatting without applying changes
fmt-check:
    docker compose exec airflow-scheduler black --check dags/ tests/

# Generate dbt docs (catalog + manifest)
docs-gen:
    docker compose exec airflow-scheduler dbt docs generate \
        --project-dir /opt/dbt/olist_dbt \
        --profiles-dir /opt/dbt/olist_dbt

# Serve dbt docs on http://localhost:18080
docs-serve:
    docker compose run --rm -p 18080:8080 --entrypoint bash airflow-scheduler \
        -c "dbt docs serve --project-dir /opt/dbt/olist_dbt --profiles-dir /opt/dbt/olist_dbt --port 8080"
