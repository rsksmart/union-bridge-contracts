echo "================ RUN SLITHER ================"
# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path"
cd ..
# run slither
sudo docker-compose up