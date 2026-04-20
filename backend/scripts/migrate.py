from backend.app.database import Base, engine
from backend.app import models  # noqa: F401


def main() -> None:
    Base.metadata.create_all(bind=engine)
    print("Schema migration bootstrap completed.")


if __name__ == "__main__":
    main()
