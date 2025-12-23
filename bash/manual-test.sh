./full-report.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_PRIVATE_KEY}"
./action-register.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_PRIVATE_KEY}" owner
./action-register.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" user2
./action-register.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_3_PRIVATE_KEY}" user3
./action-settings.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_PRIVATE_KEY}" 300 300
./action-commit.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_PRIVATE_KEY}" "I am superman" 0 false "secret0"
./action-commit.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" "I met the Pope today" 0 false "secret2"
./action-commit.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_3_PRIVATE_KEY}" "I hate cats" 0 false "secret3"
./action-guess.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" 1 1000000000000000 true "secret2"
./action-guess.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_3_PRIVATE_KEY}" 1 1000000000000000 true "secret3"
./action-reveal.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_PRIVATE_KEY}" 1 "secret0"
./action-reveal.sh ${CURRENT_NETWORK} "${SOLIDITY_STUDENT_2_PRIVATE_KEY}" 2 "secret2"