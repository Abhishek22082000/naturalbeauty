const express = require('express');
const app = express();
const connection = require('../config/connection');
const jwt = require('jsonwebtoken');


const likePost = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.id;

        await connection.query(
            'INSERT INTO likes (user_id, post_id) VALUES (?, ?)',
            [userId, postId]
        );

        return res.status(201).json({ message: 'Post liked' });

    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ message: 'Already liked' });
        }
        if (error.code === 'ER_NO_REFERENCED_ROW_2') {
            return res.status(404).json({ message: 'Post not found' });
        }
        console.error('Error liking post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

const unlikePost = async (req, res) => {
    try {
        const [result] = await connection.query(
            'DELETE FROM likes WHERE user_id = ? AND post_id = ?',
            [req.user.id, req.params.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Like not found' });
        }

        return res.status(200).json({ message: 'Post unliked' });

    } catch (error) {
        console.error('Error unliking post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

module.exports = { likePost, unlikePost };
