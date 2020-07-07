FROM atlassian/jira-software

COPY mysql-connector-java-5.1.49-bin.jar /opt/atlassian/jira/lib
COPY postgresql-42.2.14.jar /opt/atlassian/jira/lib
