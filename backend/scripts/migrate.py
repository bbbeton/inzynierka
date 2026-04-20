from pathlib import Path
import sys

CURRENT_FILE = Path(__file__).resolve()
BACKEND_DIR = CURRENT_FILE.parents[1]
REPO_ROOT = CURRENT_FILE.parents[2]

# Ensure imports work in both:
# - local runs from repo root
# - Render runs with rootDir=backend
for path in (str(REPO_ROOT), str(BACKEND_DIR)):
    if path not in sys.path:
        sys.path.insert(0, path)

try:
    # Works when executed from repository root (local dev).
    from backend.app.database import Base, engine
    from backend.app import models  # noqa: F401
except ModuleNotFoundError:
    # Works on Render because rootDir is set to backend/.
    from app.database import Base, engine
    from app import models  # noqa: F401


def main() -> None:
    Base.metadata.create_all(bind=engine)
    print("Schema migration bootstrap completed.")


if __name__ == "__main__":
    main()
