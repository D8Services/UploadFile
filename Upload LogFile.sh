#!/bin/bash


	###############################################################
	#	Copyright (c) 2020, D8 Services Ltd.  All rights reserved.  
	#											
	#	
	#	THIS SOFTWARE IS PROVIDED BY D8 SERVICES LTD. "AS IS" AND ANY
	#	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	#	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	#	DISCLAIMED. IN NO EVENT SHALL D8 SERVICES LTD. BE LIABLE FOR ANY
	#	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	#	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	#	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	#	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	#	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	#	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	#
	#
	###############################################################
	#
# https://github.com/D8Services/UploadFile
# This script requires parameters provided from Jamf
# 4 - Api Username
# 5 - Api Password
# 6 - Path to the File (log file etc)
# The script will then check if there is in fact a file there, followed by the size of the file
# If large, the script will try to compress the file and throw a worning, otherwise it simply compresses
# it and uploads it to the Computer Record.


## Function Decrypt Strings
function DecryptString() {
	# Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}
apiUser=$(DecryptString "${4}" "d278225b2cf07d19" "30aa6c4b854a14f00414c644")
apiPass=$(DecryptString "${5}" "75b1598f7dd21fea" "b86a6f04239c59b4f4cead0a")
LogFile="${6}"

tempdir=$(mktemp -d)
MaxUploadSize="26000000"
cntLogs=$(ls "${LogFile}" | wc -l)
LogName=$(basename "${LogFile}")
jssURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
id=$(curl -sku ${apiUser}:${apiPass} -H "accept: text/xml" ${jssURL}JSSResource/computers/serialnumber/$serialNumber | xmllint --xpath '/computer/general/id/text()' -)

function uploadFile() {
	curl -ku "${apiUser}":"${apiPass}" ${jssURL}JSSResource/fileuploads/computers/id/${id} -X POST -F name=@"${1}"
}
#echo "Credentials are $apiUser $apiPass, id is ${id}"
if [[ ${cntLogs} ]];then
	#Check for compression
	LogSize=$(stat -f '%z' "${LogFile}")
	if [ ${MaxUploadSize} -le ${LogSize} ];then
		echo "LogFile Too Large, attempting Compression."
		CompLog=$(echo "${tempdir}"/"${LogName}-"$(date +"%Y%m%d%H%M%S").gzip)
		gzip -cvf "${LogFile}" > "${CompLog}"
		gzip -9cvf "${LogFile}" > "${CompLog}"
		CompLogSize=$(stat -f '%z' "${CompLog}")
		if [[ ${CompLogSize} -ge ${MaxUploadSize} ]];then
			echo "ERROR: Logfile is still too large even after compression. Exiting."
			rm -rf "${tempdir}"
			exit 1
		else
			echo "File is OK for Upload after compression."
			uploadFile "${CompLog}"
		fi
	else
		echo "File is OK for Upload."
		CompLog=$(echo "${tempdir}"/"${LogName}-"$(date +"%Y%m%d%H%M%S").gzip)
		gzip -cvf "${LogFile}" > "${CompLog}"
		gzip -9cvf "${LogFile}" > "${CompLog}"
		uploadFile "${CompLog}"
	fi
else
	echo "No File Found at provided Log File Path."
fi

#Cleaning Up
rm -rf "${tempdir}"
exit 0
