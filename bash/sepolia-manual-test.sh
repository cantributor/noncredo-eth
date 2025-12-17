./full-report.sh sepolia "${SOLIDITY_STUDENT_PRIVATE_KEY}"
./action-register.sh sepolia "${SOLIDITY_STUDENT_PRIVATE_KEY}" owner
./action-register.sh sepolia "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" user1
./action-register.sh sepolia "${SOLIDITY_STUDENT_3_PRIVATE_KEY}" user2
./action-settings.sh sepolia "${SOLIDITY_STUDENT_PRIVATE_KEY}" 300 300
./action-commit.sh sepolia "${SOLIDITY_STUDENT_PRIVATE_KEY}" "I am superman" 1000 false "secret0"
./action-commit.sh sepolia "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" "I met the Pope today" 1000 false "secret1"
./action-commit.sh sepolia "${SOLIDITY_STUDENT_3_PRIVATE_KEY}" "I hate cats" 0 false "secret2"
./action-guess.sh sepolia "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" 1 1000 true "secret1"
./action-reveal.sh sepolia "${SOLIDITY_STUDENT_PRIVATE_KEY}" 1 "secret0"