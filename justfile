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
