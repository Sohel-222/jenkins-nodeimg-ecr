const AWS = require('aws-sdk');
const sns = new AWS.SNS();

exports.handler = async (event) => {
    const message = {
        Subject: "Docker Image Pushed to ECR",
        Message: JSON.stringify(event, null, 2),
        TopicArn: process.env.SNS_TOPIC_ARN
    };

    try {
        await sns.publish(message).promise();
        console.log("SNS Notification sent.");
    } catch (err) {
        console.error("Error sending SNS:", err);
    }
};

