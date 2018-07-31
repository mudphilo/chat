package tel

import (

	"github.com/mudphilo/chat/server/store"
	t "github.com/mudphilo/chat/server/store/types"
	"encoding/json"
	"path/filepath"
	"os"
	"math/rand"
	"time"
	"strconv"
	"strings"
	"bytes"
	ht "html/template"

	"github.com/mudphilo/chat/logger"
	"net/http"
	"fmt"
	"io/ioutil"
)

// Validator configuration.
type validator struct {

	TemplateFile   string `json:"msg_body_templ"`
	Password 	   string `json:"password"`
	SenderId 	   string `json:"sender_id"`
	Username 	   string `json:"username"`
	Token 		   string `json:"token"`
	DebugResponse  string `json:"debug_response"`
	MaxRetries     int    `json:"max_retries"`
	Url       	   string `json:"url"`
	htmlTempl      *ht.Template
}

// Validator configuration.
type postData struct {

	ApiKey   	   string `json:"apiKey"`
	ShortCode 	   string `json:"shortCode"`
	Message 	   string `json:"message"`
	Contacts 	   map[string]string `json:"contacts"`
	Prefix 		   string `json:"prefix"`
	Origin  	   string `json:"origin"`
	Approval       string `json:"approval"`
	IsScheduled    string `json:"is_scheduled"`
	ScheduleDate   string `json:"scheduled_date"`
	ScheduleTime   string `json:"scheduled_time"`
	CallbackURL	   string `json:"callbackURL"`
}

const (
	maxRetries  = 4// codeLength = log10(maxCodeValue)
	codeLength   = 6
	maxCodeValue = 1000000
)

// Init: initialize validator.
func (v *validator) Init(jsonconf string) error {

	var err error
	if err = json.Unmarshal([]byte(jsonconf), v); err != nil {
		return err
	}

	// If a relative path is provided, try to resolve it relative to the exec file location,
	// not whatever directory the user is in.
	if !filepath.IsAbs(v.TemplateFile) {
		basepath, err := os.Executable()
		if err == nil {
			v.TemplateFile = filepath.Join(filepath.Dir(basepath), v.TemplateFile)
		}
	}

	// Initialize random number generator.
	rand.Seed(time.Now().UnixNano())

	if v.MaxRetries == 0 {
		v.MaxRetries = maxRetries
	}

	v.htmlTempl, err = ht.ParseFiles(v.TemplateFile)
	if err != nil {
		return err
	}

	return nil
}

// Init is a noop.
func (validator) Init1(jsonconf string) error {
	return nil
}

// PreCheck validates the credential and parameters without sending an SMS or maing the call.
func (validator) PreCheck(cred string, params interface{}) error {
	// TODO: Check phone format. Format phone for E.164
	// TODO: Check phone uniqueness
	return nil
}

// Send a request for confirmation to the user: makes a record in DB  and nothing else.
func (v *validator) Request(user t.Uid, cred, lang string, params interface{}, resp string) error {
	// TODO: actually send a validation SMS or make a call to the provided `cred` here.

	// Email validator cannot accept an immmediate response.
	if resp != "" {
		return t.ErrFailed
	}

	// Generate expected response as a random numeric string between 0 and 999999
	resp = strconv.FormatInt(int64(rand.Intn(maxCodeValue)), 10)
	resp = strings.Repeat("0", codeLength-len(resp)) + resp

	body := new(bytes.Buffer)
	if err := v.htmlTempl.Execute(body, map[string]interface{}{"Code": resp}); err != nil {
		return err
	}

	// Send SMS without blocking. SMS sending may take long time.
	go v.send(cred,string(body.Bytes()))

	return store.Users.SaveCred(&t.Credential{
		User:   user.String(),
		Method: "tel",
		Value:  cred,
		Resp:   resp,
	})

	return nil
}

// This is a basic SMTP sender which connects to Gmail using login/password.

func (v *validator) send(msisdn, message string) error {

	contact := make(map[string]string)
	contact["recipients"] = msisdn

	postData := postData {
		ApiKey: v.Token,
		ShortCode: v.SenderId,
		Message: message,
		Contacts:contact,
		Prefix: "TINODE-X",
		Origin:"WEB",
		IsScheduled: "0",
		ScheduleDate: "2018-01-01",
		ScheduleTime: "00:00:00",
		CallbackURL: "",
	}

	jsonData,err := json.Marshal(postData)

	if err != nil {
		logger.Log.Fatal(err)
		return err
	}

	var jsonStr = []byte(jsonData)

	req, err := http.NewRequest("POST", v.Url, bytes.NewBuffer(jsonStr))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)
	logger.Log.Println(string(body))
	return nil;
}

// Find if user exists in the database, and if so return OK. Any response is accepted.
func (v *validator) Check(user t.Uid, resp string) error {
	// TODO: check response against a database.

	cred, err := store.Users.GetCred(user, "tel")
	if err != nil {
		return err
	}

	if cred == nil {
		// Request to validate non-existent credential.
		return t.ErrNotFound
	}

	if cred.Retries > v.MaxRetries {
		return t.ErrPolicy
	}
	if resp == "" {
		return t.ErrFailed
	}

	// Comparing with dummy response too.
	if cred.Resp == resp || v.DebugResponse == resp {
		// Valid response, save confirmation.
		return store.Users.ConfirmCred(user, "tel")
	}

	// Invalid response, increment fail counter.
	store.Users.FailCred(user, "tel")

	return t.ErrFailed
	return nil
}

// Delete deletes user's records.
func (validator) Delete(user t.Uid) error {
	return nil
}

func init() {
	//store.RegisterValidator("tel", validator{})
	store.RegisterValidator("tel", &validator{})

}
