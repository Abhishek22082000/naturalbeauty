require('dotenv').config()
const express = require('express');
const app  = express();
app.use(express.json());


const loginRoute = require('./routes/loginRoutes');
const postRoute = require('./routes/postRoute');
const likeRoute = require('./routes/likeRoute');

app.use('/likes', likeRoute);
app.use('/posts', postRoute);
app.use('/auth', loginRoute);

// app.get('/',(req, res) =>{
//     res.json({
//         message: 'API is working'
//     })
// })


app.listen(3000, '0.0.0.0', () => {
    console.log('Server running on http://0.0.0.0:3000 (reachable on your LAN IP)');
});