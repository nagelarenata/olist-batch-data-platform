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

# Restart stack (down + up)
restart:
    docker compose down
    docker compose up --build -d

# Full reset (removes volumes + orphans) - DANGER: wipes postgres metadata
nuke:
    docker compose down -v --remove-orphans

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

# Generate dbt docs (catalog + manifest) using the running scheduler container
docs-gen:
    docker compose exec airflow-scheduler dbt docs generate \
        --project-dir /opt/dbt/olist_dbt \
        --profiles-dir /opt/dbt/olist_dbt

# Start dbt docs server on http://localhost:8081 (generates + serves)
docs-up:
    docker compose --profile docs up -d dbt-docs

# Stop dbt docs server
docs-down:
    docker compose --profile docs down dbt-docs

# Show dbt docs server logs (follow)
docs-logs:
    docker compose --profile docs logs -f dbt-docs