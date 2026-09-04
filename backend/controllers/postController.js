const connection = require('../config/connection');

const createPost = async (req, res) => {
    try {
        const { caption, location } = req.body;
        const userId = req.user.id;
       
        // image comes from multer, not the body
        if (!req.file) {
            return res.status(400).json({ message: 'Image is required' });
        }

        const imageUrl = `/uploads/posts/${req.file.filename}`;

        const [result] = await connection.query(
            'INSERT INTO posts (user_id, image_url, caption, location) VALUES (?, ?, ?, ?)',
            [userId, imageUrl, caption || null, location || null]
        );

        return res.status(201).json({
            message: 'Post created successfully',
            post: {
                id: result.insertId,
                image_url: imageUrl,
                caption: caption || null,
                location: location || null
            }
        });

    } catch (error) {
        console.error('Error creating post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};



const getPost = async(req, res)=>{

}

const getUserPost = async(req, res)=>{

}


const deletePost = async(req, res)=>{

}


module.exports = {
    createPost,
    getPost,
    getUserPost,
    deletePost
}