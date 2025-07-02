echo "================ RUN SLITHER ================"
# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/.."
# run slither
sudo docker-compose up