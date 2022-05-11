// console.log("Hi There");
require('dotenv').config() // for managing env vars
const express = require('express')
const app = express()
const cors = require('cors')
const mongoose = require('mongoose')

// Should prob deal with 'connection mgt' at some point

const url = process.env.MONGODB_URI
mongoose.connect(url)
// Do I NEED to define this _id thing ? -> Prove it with a CREAETTE

const recordSchema = new mongoose.Schema({
  Name: String,
  SamAccountName: String
})

const itemSchema = new mongoose.Schema({
  _id: { type: String },
  // record: { type: String }
  Record: [recordSchema]
})
const Item = mongoose.model('users', itemSchema)

// Allows cross domain origin
app.use(cors())
// Helper tools for json formatting to/from
app.use(express.json())

// Route - for a root page request - just an identifier for HTTP Service Monitoring
app.get('/', (request, response) => { response.send('<h4>Item API Service</h4>') })

// Route - for Fetch of ALL documents
app.get('/api/items', (request, response) => {
  Item.find({}).then(items => {
    response.json(items)
  })
})


// Route - for Fetch a single record 
app.get('/api/items/:id', (request, response) => {
  const reqId = request.params.id;

  // this Mongoose method - uses a 'callback' funciton; see https://mongoosejs.com/docs/api.html#model_Model.findById
  Item.findById(reqId, (err, result) => {
    if (err) {
      console.log("Error trying to fetch record with an id of: " + reqId);
      response.status(404).end()
    }
    else { response.json(result) }
  })
})

app.get('/api/search/:id', (request, response) => {
  console.log("The Search Block Fired");
  const reqId = request.params.id;
  console.log("the QUERY content is -> " + reqId);

  // this Mongoose method - uses a 'callback' funciton; see https://mongoosejs.com/docs/api.html#model_Model.findById
//Item.find({'Record.Name' : /{reqId}/i}, (err, result) => {
// Item.find({'_id' : "f3021817-2da4-4dc2-a51c-277fd90b58bc"}, (err, result) => {
  // Item.find({'Record.Name' : "Administrator"}, (err, result) => {
    let myQry = RegExp(reqId, 'i');
    console.log(myQry);
    Item.find({'Record.Name' : myQry }, (err, result) => {
    if (err) {
      console.log("Error trying to fetch record with an id of: " + reqId);
      response.status(404).end()
    }
    else { response.json(result) }
  })
})



// Add the delete route
app.delete('/api/items/:id', (request, response) => {
  const tgtRemoveid = request.params.id;

  Item.deleteOne({ _id: tgtRemoveid }, (err, resp) => {

    /*.deleteOne() returns a short confirmation - even if record count is 0/Zed e.g. --> 
      { acknowledged: true, deletedCount: 0 } */


    if (err) {
      // Prob bro
      response.status(500).end()
    }
    else {
      console.log("DELETED");
      console.log(resp);
      response.status(204).end()
    }
  })


})

// Route - for Create a New Item
app.post('/api/items', (request, response) => {

  const postBody = request.body;

  if (!postBody.name) {
    // no "content" data provided with post - throw sad face
    return response.status(400).json(
      { error: 'content missing' }
    )
  }


  // Create an Instance of the data model
  const item = new Item({
    name: postBody.name,
    folder: postBody.folder,
	notes: postBody.notes
  })

  // Make the DB Call
  item.save().then(result => {
    response.json(result)
  })
})


// This is considered "Middleware" - processor  @ https://fullstackopen.com/en/part3/node_js_and_express#simple-web-server
const unknownEndpoint = (request, response) => {
  response.status(404).send({ error: 'unknown endpoint' })
}
app.use(unknownEndpoint)


const PORT = process.env.PORT || 3005;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})