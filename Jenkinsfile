pipeline {
    agent {
        dockerfile {
            args """--entrypoint ''"""
        }
    }

    stages {
        stage("Test") {
            steps {
                sh """
                    rake test
                """
            }
        }
    }
}
